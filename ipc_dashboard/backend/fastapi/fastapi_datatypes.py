"""
fastapi_datatypes.py - Pydantic models for request / response bodies
"""

from pydantic import BaseModel
from typing import Optional


class LoginRequest(BaseModel):
    user_uid: str
    password: str


class LoginResponse(BaseModel):
    token:    str
    user_uid: str
    role:     str
    name:     str


class LogoutRequest(BaseModel):
    token: str


class CertInfoResponse(BaseModel):
    path:            str
    filename:        str
    file_size_bytes: int
    file_size_kb:    float
    last_modified:   str
    cert_details:    dict
    available:       bool
