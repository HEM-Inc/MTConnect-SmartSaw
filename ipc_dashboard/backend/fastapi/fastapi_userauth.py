"""
fastapi_userauth.py - Authentication routes + role-based dependency
"""

import copy
import time
from collections import defaultdict
from fastapi import Request, Cookie, Depends, HTTPException, status, Body
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from fastapi_backend import *
from fastapi_utils import *
from fastapi_datatypes import *
from backend_logger import *

_bearer = HTTPBearer(auto_error=True)

# -- Rate limiter -----------------------------------------------------------
_MAX_LOGIN_ATTEMPTS = 5
_LOGIN_WINDOW_SECONDS = 15 * 60  # 15 minutes
_login_attempts = defaultdict(list)

def _check_rate_limit(client_host: str) -> bool:
    now = time.time()
    attempts = _login_attempts[client_host]
    # Keep only attempts within the window
    attempts[:] = [t for t in attempts if now - t < _LOGIN_WINDOW_SECONDS]
    if len(attempts) >= _MAX_LOGIN_ATTEMPTS:
        return False
    attempts.append(now)
    return True

# -- Session dependency -------------------------------------------------------

def get_current_user(
    request: Request,
    session_uid_cookie: str | None = Cookie(None, alias="session_uid"),
    credentials: HTTPAuthorizationCredentials | None = Depends(HTTPBearer(auto_error=False)),
) -> dict:

    befa = get_be_fastapi_obj()

    # Prefer cookie
    session_token = session_uid_cookie

    # Fallback to Bearer
    if not session_token and credentials:
        session_token = credentials.credentials

    if not session_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session token missing"
        )

    status_ok, payload = befa.smgr.validate_session(session_token)

    if status_ok != True:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=payload
        )

    return payload
'''
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    befa = get_be_fastapi_obj()
    session_uid = credentials.credentials
    status_ok, payload = befa.smgr.validate_session(session_uid)
    if status_ok != True:
        log_error("FAPI Invalid or expired session: {}".format(payload))
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=payload,
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload
'''

def require_role(*allowed_roles: str):
    def _dep(user: dict = Depends(get_current_user)) -> dict:
        log_debug("require_role check: user_role={} allowed_roles={}".format(
            user.get("role"), allowed_roles))
        if user.get("role") not in allowed_roles:
            log_error("Access denied for role={} allowed={}".format(
                user.get("role"), allowed_roles))
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return user
    return _dep


# -- Routes -------------------------------------------------------------------
@ipc_fast_api.post("/api/auth/login")
async def user_login_request(
    request: Request,
    user_data: LoginRequest = Body(...),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug("FAPI User login request for {}".format(user_data.user_uid))

    client_host = request.client.host if request.client else "unknown"
    if not _check_rate_limit(client_host):
        log_warning("FAPI Rate limit exceeded for {}".format(client_host))
        return fapi_error_response("user-login", "Too many login attempts. Please try again later.")

    beapi_params = {
        "user_uid" : user_data.user_uid,
        "password" : user_data.password
    }
    status_ok, result = await befa.thread_pool_exec(
                                      befa.api.validate_user_login,
                                      beapi_params,
                                     )
    #status_ok, result = befa.api.validate_user_login(
    #    user_uid = user_data.user_uid,
    #    password = user_data.password
    #)
    if status_ok != True:
        log_error("FAPI User login authentication failed for {}".format(user_data.user_uid))
        return fapi_error_response("user-login", "Invalid login or password", result)

    uprof_record = result

    status_ok, session_info = befa.smgr.create_user_session(
        user_uid     = user_data.user_uid,
        uprof_record = uprof_record
    )
    if status_ok != True:
        log_error("FAPI Session creation failed for {}".format(user_data.user_uid))
        return fapi_error_response("user-login", "Session creation failed")

    resp_data = {
        #"session_uid": session_info["session_uid"],
        "user_uid":    session_info["user_uid"],
        "role":        session_info["uprof_record"]["role"],
        "name":        session_info["uprof_record"]["name"],
        "timezone":    uprof_record['timezone']
    }

    response = JSONResponse(content={
        "type": "user-login",
        "status": "Success",
        "message": "User Logged in",
        "data": resp_data
    })

    cookie_conf = fapi_get_default_cookie_config()

    response.set_cookie(
        key="session_uid",
        value=session_info["session_uid"],
        httponly=cookie_conf["httponly"],
        secure=cookie_conf["secure"],
        samesite=cookie_conf["samesite"],
        max_age=3600
    )

    log_debug("FAPI User login Successful for {}".format(user_data.user_uid))
    return response

    log_debug("FAPI User login Successful for {}".format(user_data.user_uid))
    return fapi_success_response("user-login", "User Logged in", resp_data)


'''
@ipc_fast_api.post("/api/auth/logout")
async def user_logout_request(
    current_user: dict = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug("FAPI User logout request for {}".format(current_user.get("user_uid")))

    befa.smgr.delete_user_session(credentials.credentials)

    log_info("FAPI Logout successful for {}".format(current_user.get("user_uid")))
    return fapi_success_response("user-logout", "User logged out")

'''
@ipc_fast_api.post("/api/auth/logout")
async def user_logout_request(
                    request: Request,
                    session_uid_cookie: str | None = Cookie(None, alias="session_uid"),
                    credentials: HTTPAuthorizationCredentials | None = Depends(HTTPBearer(auto_error=False)),
                    current_user: dict = Depends(get_current_user),
                    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
                ):
    log_debug("FAPI User logout request for {}".format(current_user.get("user_uid")))

    # Get session token from cookie or header
    session_token = session_uid_cookie
    if not session_token and credentials:
        session_token = credentials.credentials

    if session_token:
        befa.smgr.delete_user_session(session_token)

    response = JSONResponse(content={
        "type": "user-logout",
        "status": "Success",
        "message": "User logged out"
    })

    # delete cookie
    response.delete_cookie("session_uid")

    log_info("FAPI Logout successful for {}".format(current_user.get("user_uid")))
    return response

@ipc_fast_api.get("/api/auth/me")
async def get_current_user_info(
    current_user: dict = Depends(get_current_user),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug("FAPI Get current user info for {}".format(current_user.get("user_uid")))

    beapi_params = {
        "user_uid" : current_user["user_uid"],
    }
    status_ok, result = await befa.thread_pool_exec(
                                      befa.api.get_user_profile_info,
                                      beapi_params,
                                     )
    #status_ok, result = befa.api.get_user_profile_info(
    #    user_uid = current_user["user_uid"]
    #)
    if status_ok != True:
        log_error("FAPI Get user info failed for {}".format(current_user["user_uid"]))
        return fapi_error_response("user-me", "Failed to get user info", result)

    return fapi_success_response("user-me", "User info", result)

@ipc_fast_api.get("/api/timezones")
async def get_timezones(
    current_user: dict = Depends(require_role("admin", "user")),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    status, result = await befa.thread_pool_exec(
        befa.api.get_timezone_filter,
        {}
    )

    if status != True:
        log_error("FAPI ge timezones failed for {}".format(current_user["user_uid"]))
        return fapi_error_response("timezone", "Failed", result)

    return fapi_success_response("timezone", "Success", result)

@ipc_fast_api.get("/api/timezones")
async def get_valid_timezones(
    current_user: dict = Depends(require_role("admin", "user")),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI Get timezone filter by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
        befa.api.get_timezone_filter,
        {}
    )

    if status != True:
        log_error("FAPI Get timezone filter failed")
        return fapi_error_response("get-timezones", "Failed to fetch timezones", result)

    return fapi_success_response("get-timezones", "timezones fetched", result)

@ipc_fast_api.get("/api/timezone")
async def get_timezone(
    current_user: dict = Depends(require_role("admin", "user")),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI Get timezone request by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
        befa.api.get_ipc_timezone,
        {}
    )

    if status != True:
        log_error("FAPI Get timezone failed")
        return fapi_error_response("get-timezone", "Failed to fetch timezone", result)

    return fapi_success_response("get-timezone", "Timezone fetched", result)

@ipc_fast_api.post("/api/timezone")
async def update_timezone(
    timezone: str = Body(...),
    current_user: dict = Depends(require_role("admin")),  # only admin
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI Update timezone by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
        befa.api.update_ipc_timezone,
        {"timezone": timezone}
    )

    if status != True:
        log_error("FAPI Update timezone failed")
        return fapi_error_response("update-timezone", "Failed to update timezone", result)

    return fapi_success_response("update-timezone", "Timezone updated", result)


