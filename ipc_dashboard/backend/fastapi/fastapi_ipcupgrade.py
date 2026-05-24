"""
fastapi_update.py - FastAPI routes for system update operations
"""

import json
import asyncio
from fastapi import Depends, Body, UploadFile, File, Form, Query
from fastapi.responses import StreamingResponse

from fastapi_backend import ipc_fast_api, get_be_fastapi_obj
from fastapi_userauth import require_role
from fastapi_utils import *
from backend_logger import *
from fastapi_datatypes import *


# Update — POST /api/update-start
@ipc_fast_api.post("/api/update-start")
async def start_update(
        update_request: UpdateRequest = Body(...),
        current_user: dict = Depends(require_role("admin")),
        befa=Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI start update requested by {current_user['user_uid']}")

    params = {
        "command"      : update_request.command,
        "components"   : update_request.components,
        "sudo_password": update_request.sudo_password
    }

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.start_update,
        params
    )

    if not status:
        log_error(f"FAPI start update failed: {result}")
        return fapi_error_response("update", "Failed to start update", result)

    buffer, finished = result

    async def stream():
        """
        Drain the buffer produced by run_script() and forward every dict
        as a properly JSON-encoded SSE event.

        Every entry in buffer is guaranteed to be a dict:
            {"type": "output"|"error"|"complete", "message": str, ...}

        The stream ends when a "complete" or "error" type event is seen,
        OR when finished["done"] is True and the buffer is empty.
        """
        try:
            # Immediate "started" ping so the browser knows the pipe is open
            yield f"data: {json.dumps({'type': 'start', 'message': 'Update started'})}\n\n"

            while True:
                # Drain everything currently queued
                while buffer:
                    event = buffer.pop(0)

                    # Safety: if somehow a plain string slipped in, wrap it
                    if isinstance(event, str):
                        event = {"type": "output", "message": event}

                    yield f"data: {json.dumps(event)}\n\n"

                    # A "complete" or "error" event means the script is done
                    if event.get("type") in ("complete", "error"):
                        yield "data: [DONE]\n\n"
                        return

                # Script thread finished — drain any last messages then stop
                if finished["done"]:
                    while buffer:
                        event = buffer.pop(0)
                        if isinstance(event, str):
                            event = {"type": "output", "message": event}
                        yield f"data: {json.dumps(event)}\n\n"
                        if event.get("type") in ("complete", "error"):
                            break

                    yield "data: [DONE]\n\n"
                    return

                # Nothing ready yet — yield a keepalive comment and wait
                yield ": keepalive\n\n"
                await asyncio.sleep(0.2)

        except asyncio.CancelledError:
            log_debug("FAPI update stream cancelled by client")

        except Exception as e:
            log_error(f"FAPI update stream error: {e}")
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control"    : "no-cache",
            "Connection"       : "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )


# File structure
@ipc_fast_api.get("/api/files-structure")
async def get_structure(
        components  : List[str] = Query(None),
        current_user: dict      = Depends(require_role("admin")),
        befa                    = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI get files structure requested by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.get_file_structure,
        {"params": components}
    )

    if not status:
        log_error("FAPI get file structure failed")
        return fapi_error_response("file-structure", "Failed", result)

    log_debug("FAPI get file structure request successful")
    return fapi_success_response("file-structure", "Success", result)


# File content
@ipc_fast_api.get("/api/files-content")
async def get_file(
        path        : str  = Query(...),
        current_user: dict = Depends(require_role("admin")),
        befa               = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI get files content requested by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.get_file_content,
        {"file_path": path}
    )

    if not status:
        log_error("FAPI get files content request failed")
        return fapi_error_response("files-content", "Get files content Failed", result)

    log_debug("FAPI get files content request successful")
    return fapi_success_response("files-content", "Get files content successful", result)


# File edit (acquire lock)
@ipc_fast_api.post("/api/file-edit")
async def acquire_lock(
        file_path   : str  = Body(...),
        current_user: dict = Depends(require_role("admin")),
        befa               = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI file edit request by {current_user['user_uid']}")

    params = {
        "path": file_path,
        "user": current_user["user_uid"]
    }

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.acquire_file_lock,
        {"params": params}
    )

    if not status:
        log_error("FAPI file edit request failed")
        return fapi_error_response("file-edit", "File edit request Failed", result)

    log_debug("FAPI file edit request successful")
    return fapi_success_response("file-edit", "File edit request success", result)


# File heartbeat (refresh lock)
@ipc_fast_api.post("/api/file-heartbeat")
async def file_heartbeat(
        file_path   : str  = Body(...),
        current_user: dict = Depends(require_role("admin")),
        befa               = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI file heartbeat by {current_user['user_uid']}")

    params = {
        "path": file_path,
        "user": current_user["user_uid"]
    }

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.refresh_lock,
        {"params": params}
    )

    if not status:
        log_error("FAPI file heartbeat request failed")
        return fapi_error_response("heartbeat", "File heartbeat request Failed", result)

    log_debug("FAPI file heartbeat request successful")
    return fapi_success_response("heartbeat", "File heartbeat request success", result)


# File lock status
@ipc_fast_api.get("/api/file-status")
async def lock_status(
        path        : str  = Query(...),
        current_user: dict = Depends(require_role("admin")),
        befa               = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI get file lock status by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.get_lock_status,
        {"params": {"path": path}}
    )

    if not status:
        log_error("FAPI get file lock status request failed")
        return fapi_error_response("lock-status", "Get file status request failed", result)

    log_debug("FAPI get file lock status request successful")
    return fapi_success_response("lock-status", "OK", result)


# File save
@ipc_fast_api.post("/api/file-save")
async def save_file(
        request     : FileInfoSave = Body(...),
        current_user: dict         = Depends(require_role("admin")),
        befa                       = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI save file by {current_user['user_uid']}")

    req        = request.dict()
    req["user"] = current_user["user_uid"]

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.save_file,
        {"params": req}
    )

    if not status:
        log_error("FAPI save file request failed")
        return fapi_error_response("file-save", "File save request failed", result)

    log_debug("FAPI save file request successful")
    return fapi_success_response("file-save", "Saved", result)


# File discard (release lock)
@ipc_fast_api.post("/api/file-discard")
async def release_file(
        file_path   : str  = Body(...),
        current_user: dict = Depends(require_role("admin")),
        befa               = Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI file discard by {current_user['user_uid']}")

    params = {
        "path": file_path,
        "user": current_user["user_uid"]
    }

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.release_file,
        {"params": params}
    )

    if not status:
        log_error("FAPI file discard request failed")
        return fapi_error_response("file-release", "File discard failed", result)

    return fapi_success_response("file-release", "File discard successful", result)


# File upload
@ipc_fast_api.post("/api/file-upload")
async def upload_file(
        dir_path    : str        = Form(...),
        file        : UploadFile = File(...),
        current_user: dict       = Depends(require_role("admin")),
        befa                     = Depends(get_be_fastapi_obj)
):
    content = await file.read()

    params = {
        "dir_path": dir_path,
        "filename": file.filename,
        "content" : content
    }

    status, result = await befa.thread_pool_exec(
        befa.api.ipc_update.upload_file,
        {"params": params}
    )

    if not status:
        log_error("FAPI upload file request failed")
        return fapi_error_response("file-upload", "Failed", result)

    log_debug("FAPI upload file request successful")
    return fapi_success_response("file-upload", "File uploaded successfully", result)
