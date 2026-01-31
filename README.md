from fastapi import FastAPI, Query, HTTPException
from typing import Dict, Any, List, Optional, Tuple
import heapq

from app.db import dynamo_resource
from app.keys import (
    access_pk, items_pk, items_sk, urgency_pk, urgency_sk,
    today_yyyymmdd, utc_now_iso, bucket_for, DEFAULT_BUCKETS
)
from app.schemas import ItemCreate, ItemPatch, BoardResponse
from app.cursor import decode_cursor, encode_cursor, esk_from_jsonable, esk_to_jsonable

app = FastAPI(title="DynamoDB Urgency Board")

def access_studies(user_id: str) -> List[str]:
    access = dynamo_resource().Table("Access")
    resp = access.query(
        KeyConditionExpression="pk = :pk",
        ExpressionAttributeValues={":pk": access_pk(user_id)},
    )
    studies = []
    for it in resp.get("Items", []):
        # SK: S#<study>#R#<role>
        parts = it["sk"].split("#")
        studies.append(parts[1])
    return studies

@app.get("/me/studies")
def my_studies(user_id: str = Query(...)):
    access = dynamo_resource().Table("Access")
    resp = access.query(
        KeyConditionExpression="pk = :pk",
        ExpressionAttributeValues={":pk": access_pk(user_id)},
    )
    out = []
    for it in resp.get("Items", []):
        parts = it["sk"].split("#")
        out.append({"study_id": parts[1], "role": parts[3]})
    return {"user_id": user_id, "studies": out}

@app.post("/items")
def create_item(body: ItemCreate, buckets: int = Query(default=DEFAULT_BUCKETS, ge=1, le=200)):
    items = dynamo_resource().Table("Items")
    idx = dynamo_resource().Table("UrgencyIndex")

    day = today_yyyymmdd()
    ts = utc_now_iso()
    b = bucket_for(body.item_id, buckets=buckets)

    # Items: fonte
    item = {
        "pk": items_pk(body.item_id),
        "sk": items_sk(body.type),
        "item_id": body.item_id,
        "type": body.type,
        "study_id": body.study_id,
        "urgency": int(body.urgency),
        "day": day,
        "bucket": int(b),
        "updated_at": ts,
        "status": body.status,
        "title": body.title,
        "attrs": body.attrs,
        "version": 1,
        "last_request_id": "init",
    }
    items.put_item(Item=item)

    # UrgencyIndex: view para ordenar
    pk = urgency_pk(body.study_id, body.type, day, b)
    sk = urgency_sk(body.urgency, ts, body.item_id)
    idx.put_item(Item={
        "pk": pk,
        "sk": sk,
        "study_id": body.study_id,
        "type": body.type,
        "day": day,
        "bucket": int(b),
        "urgency": int(body.urgency),
        "item_id": body.item_id,
    })

    return {"ok": True, "item": item, "index": {"pk": pk, "sk": sk}}

@app.patch("/items/{item_id}")
def patch_item(item_id: str, body: ItemPatch, buckets: int = Query(default=DEFAULT_BUCKETS, ge=1, le=200)):
    items = dynamo_resource().Table("Items")
    idx = dynamo_resource().Table("UrgencyIndex")

    # Load current
    pk = items_pk(item_id)
    # como SK depende do type, precisamos descobrir via Query por PK
    resp = items.query(
        KeyConditionExpression="pk = :pk",
        ExpressionAttributeValues={":pk": pk},
        Limit=1
    )
    if not resp.get("Items"):
        raise HTTPException(status_code=404, detail="Item not found")

    cur = resp["Items"][0]

    # Idempotência simples: se request_id já aplicado, retorna
    if cur.get("last_request_id") == body.request_id:
        return {"ok": True, "idempotent": True, "item": cur}

    old = {
        "study_id": cur["study_id"],
        "type": cur["type"],
        "day": cur["day"],
        "bucket": int(cur["bucket"]),
        "urgency": int(cur["urgency"]),
        "updated_at": cur["updated_at"],
    }

    # Apply updates
    new_urgency = old["urgency"] if body.urgency is None else int(body.urgency)
    new_title = cur.get("title") if body.title is None else body.title
    new_status = cur.get("status") if body.status is None else body.status
    new_attrs = cur.get("attrs", {}) if body.attrs is None else body.attrs

    new_day = today_yyyymmdd()
    ts = utc_now_iso()
    b = bucket_for(item_id, buckets=buckets)

    # Update Items (fonte)
    new_version = int(cur.get("version", 1)) + 1
    items.put_item(Item={
        **cur,
        "urgency": new_urgency,
        "title": new_title,
        "status": new_status,
        "attrs": new_attrs,
        "day": new_day,
        "bucket": int(b),
        "updated_at": ts,
        "version": new_version,
        "last_request_id": body.request_id
    })

    # Reindex: delete old index entry (best-effort)
    old_pk = urgency_pk(old["study_id"], old["type"], old["day"], old["bucket"])
    old_sk = urgency_sk(old["urgency"], old["updated_at"], item_id)
    idx.delete_item(Key={"pk": old_pk, "sk": old_sk})

    # Put new index entry
    new_pk = urgency_pk(old["study_id"], old["type"], new_day, b)
    new_sk = urgency_sk(new_urgency, ts, item_id)
    idx.put_item(Item={
        "pk": new_pk,
        "sk": new_sk,
        "study_id": old["study_id"],
        "type": old["type"],
        "day": new_day,
        "bucket": int(b),
        "urgency": new_urgency,
        "item_id": item_id,
    })

    return {"ok": True, "old_index": {"pk": old_pk, "sk": old_sk}, "new_index": {"pk": new_pk, "sk": new_sk}}

def query_bucket_page(
    table,
    pk: str,
    limit: int,
    exclusive_start_key: Optional[Dict[str, Any]] = None
) -> Tuple[List[Dict[str, Any]], Optional[Dict[str, Any]]]:
    kwargs = {
        "KeyConditionExpression": "pk = :pk",
        "ExpressionAttributeValues": {":pk": pk},
        "Limit": limit,
    }
    if exclusive_start_key:
        kwargs["ExclusiveStartKey"] = exclusive_start_key
    resp = table.query(**kwargs)
    return resp.get("Items", []), resp.get("LastEvaluatedKey")

@app.get("/board", response_model=BoardResponse)
def board(
    user_id: str = Query(...),
    types: str = Query("DataQuery,SafetyEvent"),
    day: Optional[str] = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    buckets: int = Query(default=DEFAULT_BUCKETS, ge=1, le=200),
    cursor: Optional[str] = Query(default=None),
):
    """
    Board com paginação:
    - RBAC (Access)
    - Para cada study+type: consulta todos buckets com ExclusiveStartKey (cursor)
    - Faz merge ordenado por SK (U#inv_urgency...) usando heap (k-way merge)
    - Retorna next_cursor por pk (um por bucket)
    """
    if day is None:
        day = today_yyyymmdd()

    studies = access_studies(user_id)
    type_list = [t.strip() for t in types.split(",") if t.strip()]
    groups: Dict[str, List[Dict[str, Any]]] = {t: [] for t in type_list}

    cur_state = decode_cursor(cursor)  # { "eks": { "<pk>": { ... } } }
    eks_map: Dict[str, Any] = cur_state.get("eks", {})

    idx = dynamo_resource().Table("UrgencyIndex")
    next_eks: Dict[str, Any] = {}

    # Para cada (study,type): fazemos merge dos buckets e retornamos top 'limit'
    for study_id in studies:
        for t in type_list:
            # 1) Busca uma “page” por bucket
            pages: List[List[Dict[str, Any]]] = []
            bucket_pks: List[str] = []
            bucket_les: List[Optional[Dict[str, Any]]] = []

            per_bucket_fetch = max(5, min(limit, 25))  # pequeno, mas suficiente p/ merge

            for b in range(buckets):
                pk = urgency_pk(study_id, t, day, b)
                bucket_pks.append(pk)
                esk_json = eks_map.get(pk)
                esk = esk_from_jsonable(esk_json) if esk_json else None

                items, lek = query_bucket_page(idx, pk=pk, limit=per_bucket_fetch, exclusive_start_key=esk)
                pages.append(items)
                bucket_les.append(lek)

                if lek:
                    next_eks[pk] = esk_to_jsonable(lek)
                else:
                    # se não tem mais, omitimos no próximo cursor
                    pass

            # 2) k-way merge por SK (já vem ordenado dentro do bucket)
            heap = []
            for i, arr in enumerate(pages):
                if arr:
                    heapq.heappush(heap, (arr[0]["sk"], i, 0, arr[0]))

            merged: List[Dict[str, Any]] = []
            while heap and len(merged) < limit:
                _, bi, ai, item = heapq.heappop(heap)
                merged.append(item)
                nxt = ai + 1
                if nxt < len(pages[bi]):
                    nxt_item = pages[bi][nxt]
                    heapq.heappush(heap, (nxt_item["sk"], bi, nxt, nxt_item))

            # 3) Entra no grupo do type
            for it in merged:
                groups[t].append({
                    "study_id": it["study_id"],
                    "type": it["type"],
                    "item_id": it["item_id"],
                    "urgency": int(it["urgency"]),
                    "bucket": int(it.get("bucket", 0)),
                })

    # Mantém cada type ordenado por urgência desc (pra ficar “óbvio” na resposta)
    for t in groups:
        groups[t].sort(key=lambda x: (-x["urgency"], x["item_id"]))

    next_cursor = encode_cursor({"eks": next_eks}) if next_eks else None
    return BoardResponse(user_id=user_id, day=day, groups=groups, next_cursor=next_cursor)
