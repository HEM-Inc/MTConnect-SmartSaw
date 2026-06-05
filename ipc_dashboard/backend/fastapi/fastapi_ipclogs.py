from fastapi import Depends, HTTPException, Request, Query
from fastapi.responses import StreamingResponse
import json
import asyncio
import queue

from fastapi_backend import ipc_fast_api, get_be_fastapi_obj
from fastapi_userauth import require_role
from fastapi_utils import *
from backend_logger import *


# How long (seconds) to wait on the queue before checking
# for client disconnect.  Short enough to feel responsive,
# long enough not to spin.
_POLL_INTERVAL = 0.25

# Keepalive comment sent over SSE so Nginx / browsers do not
# close an idle connection.  Must be <= proxy read-timeout.
_HEARTBEAT_INTERVAL = 15.0


@ipc_fast_api.get("/api/docker-logs")
async def docker_logs_stream(
    request: Request,
    current_user: dict = Depends(require_role("admin")),
    befa=Depends(get_be_fastapi_obj),
    container: str = Query(...)
):
    """
    SSE endpoint — streams Docker logs for *container*.

    Connection lifetime
    -------------------
    Stays open until ONE of:
      • The browser / client explicitly closes the tab / EventSource.
      • A real Docker / OS error is reported by the worker.
      • select_container() is called with a new container (server side).

    It does NOT close just because there are no new log lines.
    """

    log_info(
        f"Docker logs SSE connect by {current_user['user_uid']} "
        f"for container '{container}'"
    )

    ############################################################
    # REGISTER CLIENT
    ############################################################
    status, client_queue = befa.api.ipc_logs.connect()

    if not status:
        log_error("Docker logs SSE connect failed")
        raise HTTPException(status_code=500, detail="Failed to connect to log stream")

    ############################################################
    # START / SWITCH LOG WORKER
    ############################################################
    befa.api.ipc_logs.select_container(container)

    ############################################################
    # SSE GENERATOR
    ############################################################
    async def event_stream():

        last_heartbeat = asyncio.get_event_loop().time()

        try:

            # -----------------------------------------------
            # HANDSHAKE
            # -----------------------------------------------
            yield f"data: {json.dumps({'type': 'connected', 'container': container})}\n\n"

            # -----------------------------------------------
            # MAIN LOOP
            # Runs forever until a real disconnect / error.
            # Empty queue  →  send heartbeat, keep looping.
            # -----------------------------------------------
            while True:

                # -------------------------------------------
                # CHECK REAL CLIENT DISCONNECT
                # Shield so Uvicorn cancellation of
                # is_disconnected() doesn't kill the loop.
                # -------------------------------------------
                try:
                    disconnected = await asyncio.shield(
                        asyncio.wait_for(
                            request.is_disconnected(),
                            timeout=0.05
                        )
                    )
                except (asyncio.TimeoutError, asyncio.CancelledError):
                    disconnected = False

                if disconnected:
                    log_debug(f"Docker SSE — client disconnected: '{container}'")
                    break

                # -------------------------------------------
                # DRAIN QUEUE  (non-blocking)
                # -------------------------------------------
                try:
                    msg = client_queue.get_nowait()

                except queue.Empty:
                    # No messages — sleep briefly, then maybe heartbeat.
                    await asyncio.sleep(_POLL_INTERVAL)

                    now = asyncio.get_event_loop().time()
                    if now - last_heartbeat >= _HEARTBEAT_INTERVAL:
                        # SSE comment — invisible to EventSource but
                        # resets proxy idle timers.
                        yield ": heartbeat\n\n"
                        last_heartbeat = now

                    continue

                except Exception as e:
                    log_error(f"Docker SSE queue error: {e}")
                    break

                # -------------------------------------------
                # FORWARD MESSAGE
                # -------------------------------------------
                msg_type = msg.get("type")

                if msg_type == "heartbeat":
                    # Worker-level heartbeat → SSE comment.
                    yield ": heartbeat\n\n"
                    last_heartbeat = asyncio.get_event_loop().time()

                else:
                    yield f"data: {json.dumps(msg)}\n\n"

        except asyncio.CancelledError:
            # Uvicorn cancelled the coroutine (server shutting down,
            # or transport-level close).  Check whether the client
            # actually disconnected or if it's a spurious cancel.
            log_debug(f"Docker SSE coroutine cancelled: '{container}'")

        finally:
            # Deregister THIS client only.
            # Worker keeps running for other clients / reconnects.
            befa.api.ipc_logs.disconnect(client_queue)
            log_debug(f"Docker SSE cleaned up: '{container}'")

    ############################################################
    # STREAMING RESPONSE
    ############################################################
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control":     "no-cache",
            "Connection":        "keep-alive",
            "X-Accel-Buffering": "no",   # prevent Nginx buffering
        }
    )
