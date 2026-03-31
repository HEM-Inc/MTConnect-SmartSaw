import time, sys
import json
import os
from fastapi import FastAPI, Response

from fastapi_backend import *
from backend_utils import *
from backend_config import *
from backend_api import *
import traceback

sys.path.insert(3, '../config')
sys.path.insert(4, '../common')

import asyncio
from concurrent.futures import ThreadPoolExecutor
from functools import partial

async def fapi_thread_pool_exec(function_name, params):
    loop = asyncio.get_running_loop()
    try :
        with ThreadPoolExecutor() as pool:
            partial_function =  partial(function_name, **params)
            status, result = await loop.run_in_executor(pool, partial_function)
            #log_debug("Status {} result: {}".format(status, result))
            return status, result
    except Exception as e:
        stack_trace = traceback.format_exc()
        log_error("Fast API Thread pool async exec Exception")
        log_error("Function: {}".format(function_name))
        log_error("Params  : {}".format(params))
        log_error("Stack trace is: {}".format(stack_trace))
        return False, "Thread pool Exception"
    return False, "Unknown error"

def fapi_error_response(request: str, msg: str, data = None):
    error_resp_data = {
                     "type" : request,
                     "status" : "Failed",
                     "message" : msg,
                     "data" : data if data else [] 
                    }
    return error_resp_data

def fapi_success_response(request: str, msg: str, data = None):
    success_resp_data = {
                     "type" : request,
                     "status" : "Success",
                     "message" : msg,
                     "data" : data if data else []
                    }
    return success_resp_data


def fapi_file_response(content: bytes, filename: str, media_type: str):
    return Response(
            content= content,
            media_type= media_type,
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )

def fapi_load_json_params(json_string: str):
    try:
        json_data = json.loads(json_string)
    except json.JSONDecodeError:
        log_error("Invalid json format")
        return False, "Invalid json format"

def fapi_get_default_cookie_config():
    """
    Returns default cookie configuration
    """
    
    return {
        "secure" : False,
        "httponly" : True,
        "samesite" : "lax",
        "key": "key",
    }
    
def fapi_get_device_type_from_useragent(user_agent: str) -> str:
    """
    Detects device type from User-Agent string.
    Defaults to "web" unless mobile indicators are found.
    """
    if not user_agent:
        return "web"   # default

    ua = user_agent.lower()

    # Android apps (React Native / okhttp client)
    if "okhttp" in ua:
        return "mobile"

    # iOS devices (React Native / Safari-style UA)
    if "cfnetwork" in ua or "darwin" in ua:
        return "mobile"

    # Android mobile browsers
    if "android" in ua and "mobile" in ua:
        return "web"

    # Other common mobile keywords
    if any(keyword in ua for keyword in ["opera mini", "blackberry"]):
        return "mobile"

    # Otherwise fallback = web
    return "web"
