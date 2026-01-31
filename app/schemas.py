from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

class ItemCreate(BaseModel):
    item_id: str
    type: str
    study_id: str
    urgency: int = Field(ge=0, le=9999)
    title: str = "Untitled"
    status: str = "OPEN"
    attrs: Dict[str, Any] = {}

class ItemPatch(BaseModel):
    urgency: Optional[int] = Field(default=None, ge=0, le=9999)
    title: Optional[str] = None
    status: Optional[str] = None
    attrs: Optional[Dict[str, Any]] = None
    request_id: str  # idempotência simples

class BoardItem(BaseModel):
    study_id: str
    type: str
    item_id: str
    urgency: int
    bucket: int

class BoardResponse(BaseModel):
    user_id: str
    day: str
    groups: Dict[str, List[BoardItem]]
    next_cursor: Optional[str] = None
