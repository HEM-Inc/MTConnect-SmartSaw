import json
import asyncio
from fastapi import Depends, HTTPException
from fastapi.responses import StreamingResponse

from fastapi_backend import ipc_fast_api, get_be_fastapi_obj
from fastapi_userauth import require_role
from fastapi_utils import *
from backend_logger import *


@ipc_fast_api.get("/api/docker-status")
async def get_docker_status(
                        current_user: dict = Depends(require_role("admin")),
                        befa = Depends(get_be_fastapi_obj)
                        ):
    log_debug(f"FAPI Docker status by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
                                            befa.api.ipc_status.get_status,   
                                            {}
                                            )
    if status != True:
        log_error("FAPI get docker status request failed")
        return fapi_error_response("docker-status", "Failed", result)

    log_debug("FAPI get docker status request successful")
    return fapi_success_response("docker-status", "Success", result)


@ipc_fast_api.get("/api/docker-containers")
async def get_containers(
                    current_user: dict = Depends(require_role("admin")),
                    befa = Depends(get_be_fastapi_obj)
                    ):
    status, result = await befa.thread_pool_exec(
                                    befa.api.ipc_status.get_containers, 
                                    {}
                                    )
    if status != True:
        log_error("FAPI get docker containers status request failed")
        return fapi_error_response("docker-containers", "Failed", result)

    log_debug("FAPI get docker containers status request successful")
    return fapi_success_response("docker-containers", "Success", result)


@ipc_fast_api.get("/api/docker-stream")
async def docker_stream(
                    current_user: dict = Depends(require_role("admin")),
                    befa = Depends(get_be_fastapi_obj)
                    ):
    log_info(f"FAPI Docker stream by {current_user['user_uid']}")

    status, result = await befa.thread_pool_exec(
                                befa.api.ipc_status.connect,
                                {}
                                )

    if status != True:
        log_error("FAPI docker stream failed to connect")
        raise HTTPException(500, "Failed to connect")

    client_buffer, success = result

    if success != True:
        raise HTTPException(429, "Too many connections")

    async def event_stream():
        try:
            yield f"data: {json.dumps({'type': 'connected'})}\n\n"

            while True:
                while client_buffer:
                    msg = client_buffer.pop(0)
                    yield f"data: {json.dumps(msg)}\n\n"

                await asyncio.sleep(0.2)

        except asyncio.CancelledError:
            log_debug("Docker SSE cancelled")

        finally:
            await befa.thread_pool_exec(
                                befa.api.ipc_status.disconnect,
                                {"client_buffer": client_buffer}
                                )
            log_debug("Docker SSE cleaned up")

    return StreamingResponse(event_stream(),
                            media_type="text/event-stream",
                            headers={
                                "Cache-Control": "no-cache",
                                "Connection": "keep-alive",
                                "X-Accel-Buffering": "no"
                            }
                        )
