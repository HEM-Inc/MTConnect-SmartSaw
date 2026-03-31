"""
backend_utils.py - Shared utility helpers
"""

import json
import copy
import os
from threading import Lock
from backend_logger import *


def allocate_lock():
    return Lock()


def read_config_file(cfg_file):
    if not os.path.isfile(cfg_file):
        log_error(f"Config file {cfg_file} does not exist")
        return False, f"File not found: {cfg_file}"
    try:
        with open(cfg_file) as f:
            data = json.load(f)
        return True, copy.deepcopy(data)
    except (IOError, ValueError) as e:
        log_error(f"Config file {cfg_file} read/parse error: {e}")
        return False, str(e)


def string_none_or_empty(param):
    if param is None:
        return True
    if not isinstance(param, str):
        return True
    return param.strip() == ""


def show_data(in_data, subject="", prefix="", indent=""):
    if isinstance(in_data, dict):
        log_debug(f"{subject} dict has {len(in_data)} entries")
        for k, v in in_data.items():
            log_debug(f"{indent}{prefix} Key:{k}  val:{v}")
    elif isinstance(in_data, list):
        log_debug(f"{subject} list has {len(in_data)} entries")
        for v in in_data:
            log_debug(f"{indent}{prefix} {v}")
