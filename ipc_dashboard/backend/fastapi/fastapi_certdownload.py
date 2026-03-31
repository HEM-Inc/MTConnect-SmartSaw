"""
fastapi_certs.py - Certificate download routes
Accessible by both 'admin' and 'user' roles.
"""

import os
from fastapi import Depends

from fastapi_backend import ipc_fast_api, get_be_fastapi_obj
from fastapi_userauth import require_role
from fastapi_utils import *
from backend_logger import *


@ipc_fast_api.get("/api/certs/info")
async def get_cert_info(
    current_user: dict = Depends(require_role("admin", "user")),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug("FAPI Get cert info request by {}".format(current_user["user_uid"]))

    beapi_params = {}
    status, result = await befa.thread_pool_exec(
                                      befa.api.get_ca_cert_info,
                                      beapi_params,
                                     )
    #status, result = befa.api.get_ca_cert_info()
    if status != True:
        log_error("FAPI Get cert info failed: {}".format(result))
        return fapi_error_response("cert-info", "Failed to get certificate info", result)

    log_info("FAPI Cert info fetched by {}".format(current_user["user_uid"]))
    return fapi_success_response("cert-info", "Certificate info", result)

@ipc_fast_api.get("/api/certs/ca")
async def download_ca_cert(
    current_user: dict = Depends(require_role("admin", "user")),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug("FAPI CA cert download request by {}".format(current_user["user_uid"]))

    beapi_params = {}
    status, cert_path = await befa.thread_pool_exec(
        befa.api.get_ca_cert_path,
        beapi_params,
    )

    if status != True:
        log_error("FAPI CA cert path unavailable")
        return fapi_error_response("cert-download", "Certificate path unavailable", cert_path)

    if not os.path.isfile(cert_path):
        log_error("FAPI CA cert file not found at {}".format(cert_path))
        return fapi_error_response(
            "cert-download",
            "Certificate file not found",
            "Path: {}".format(cert_path)
        )

    log_info("FAPI CA cert download by {} role={}".format(
        current_user["user_uid"], current_user["role"]))

    with open(cert_path, "rb") as f:
        cert_bytes = f.read()

    from fastapi.responses import Response

    return Response(
        content=cert_bytes,
        media_type="application/x-x509-ca-cert",
        headers={
            "Content-Disposition": "attachment; filename=ca.crt"
        }
    )
'''
@ipc_fast_api.get("/api/certs/ca")
async def download_ca_cert(
    current_user: dict = Depends(require_role("admin", "user")),
    befa: IpcBackendFastApi = Depends(get_be_fastapi_obj)
):
    log_debug("FAPI CA cert download request by {}".format(current_user["user_uid"]))
   
    beapi_params = {}
    status, cert_path = await befa.thread_pool_exec(
                                      befa.api.get_ca_cert_path,
                                      beapi_params,
                                     )
    #status, cert_path = befa.api.get_ca_cert_path()
    if status != True:
        log_error("FAPI CA cert path unavailable")
        return fapi_error_response("cert-download", "Certificate path unavailable", cert_path)

    if not os.path.isfile(cert_path):
        log_error("FAPI CA cert file not found at {}".format(cert_path))
        return fapi_error_response(
            "cert-download",
            "Certificate file not found",
            "Path: {}".format(cert_path)
        )

    log_info("FAPI CA cert download by {} role={}".format(
        current_user["user_uid"], current_user["role"]))

    with open(cert_path, "rb") as f:
        cert_bytes = f.read()

    return fapi_file_response(
        content    = cert_bytes,
        filename   = "ca.crt",
        media_type = "application/x-x509-ca-cert"
    )
'''
