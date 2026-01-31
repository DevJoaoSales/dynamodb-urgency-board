import base64
import json
from typing import Any, Dict, Optional

def encode_cursor(state: Dict[str, Any]) -> str:
    raw = json.dumps(state, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8")

def decode_cursor(cursor: Optional[str]) -> Dict[str, Any]:
    if not cursor:
        return {}
    raw = base64.urlsafe_b64decode(cursor.encode("utf-8"))
    return json.loads(raw)

def esk_to_jsonable(esk: Dict[str, Any]) -> Dict[str, Any]:
    # boto3 retorna valores já JSON-friendly (str/int), mas deixamos explícito
    return esk

def esk_from_jsonable(esk: Dict[str, Any]) -> Dict[str, Any]:
    return esk
