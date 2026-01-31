import hashlib
from datetime import datetime, timezone

BUCKETS = 20  # depois você ajusta

def today_yyyymmdd() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d")

def bucket_for(item_id: str, buckets: int = BUCKETS) -> int:
    h = hashlib.md5(item_id.encode("utf-8")).hexdigest()
    return int(h[:8], 16) % buckets

def inv_urgency(urgency: int) -> str:
    # Dynamo ordena asc; queremos desc -> invertido e zero-pad
    return f"{9999 - int(urgency):04d}"

def items_pk(item_id: str) -> str:
    return f"ITEM#{item_id}"

def items_sk(item_type: str) -> str:
    return f"META#{item_type}"

def urgency_pk(study_id: str, item_type: str, day: str, bucket: int) -> str:
    return f"S#{study_id}#T#{item_type}#D#{day}#B#{bucket}"

def urgency_sk(urgency: int, updated_at: str, item_id: str) -> str:
    return f"U#{inv_urgency(urgency)}#TS#{updated_at}#I#{item_id}"

def access_pk(user_id: str) -> str:
    return f"U#{user_id}"

def access_sk(study_id: str, role: str) -> str:
    return f"S#{study_id}#R#{role}"
