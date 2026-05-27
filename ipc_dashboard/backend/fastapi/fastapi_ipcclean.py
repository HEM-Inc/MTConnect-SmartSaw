import json
import asyncio
from fastapi import Depends, Body, UploadFile, File, Form, Query
from fastapi.responses import StreamingResponse

from fastapi_backend import ipc_fast_api, get_be_fastapi_obj
from fastapi_userauth import require_role
from fastapi_utils import *
from backend_logger import *
from fastapi_datatypes import *


# Update — POST /api/clean-start
@ipc_fast_api.post("/api/clean")
async def start_clean(
        clean_request: UpdateRequest = Body(...),
        current_user: dict = Depends(require_role("admin")),
        befa=Depends(get_be_fastapi_obj)
):
    log_debug(f"FAPI start clean requested by {current_user['user_uid']}")

    params = {
        "command"      : clean_request.command,
        "components"   : clean_request.components,
        "sudo_password": clean_request.sudo_password
    }

    status, result = await befa.thread_pool_exec(
        befa.api.start_clean,
        params
    )

    if not status:
        log_error(f"FAPI start clean failed: {result}")
        return fapi_error_response("clean", "Failed to start clean", result)

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
            yield f"data: {json.dumps({'type': 'start', 'message': 'Clean started'})}\n\n"

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
            log_debug("FAPI clean stream cancelled by client")

        except Exception as e:
            log_error(f"FAPI clean stream error: {e}")
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
    

