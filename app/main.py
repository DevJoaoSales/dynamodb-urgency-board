from fastapi import FastAPI, Query
from app.db import dynamo
from app.keys import access_pk

app = FastAPI(title="DynamoDB Urgency Board")

@app.get("/me/studies")
def my_studies(user_id: str = Query(...)):
    table = dynamo().Table("Access")
    resp = table.query(
        KeyConditionExpression="pk = :pk",
        ExpressionAttributeValues={":pk": access_pk(user_id)},
    )
    # SK = S#<study>#R#<role>
    out = []
    for it in resp.get("Items", []):
        sk = it["sk"]
        parts = sk.split("#")
        out.append({"study_id": parts[1], "role": parts[3]})
    return {"user_id": user_id, "studies": out}
