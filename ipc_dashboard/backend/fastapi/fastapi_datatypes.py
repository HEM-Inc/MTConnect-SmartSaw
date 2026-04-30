"""
fastapi_datatypes.py - Pydantic models for request / response bodies
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any


class LoginRequest(BaseModel):
    user_uid: str
    password: str

class ComponentConfig(BaseModel):
    name: str
    config_file: Optional[str] = ""
    data_file: Optional[str] = ""
    serial_number: Optional[str] = ""
    bridge: Optional[bool] = False
    reinit: Optional[bool] = False
    materials: Optional[bool] = False
    version: Optional[str] = ""


class UpdateRequest(BaseModel):
    command: str
    components: Optional[List[Dict[str, Any]]] = Field(default=None)
    sudo_password: Optional[str] = Field(default=None)


class FileInfoSave(BaseModel):
    path: str
    content: str



