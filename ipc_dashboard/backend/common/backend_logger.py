"""
backend_logger.py - Custom logger with extended log levels
"""

import logging
from logging.handlers import RotatingFileHandler
import os
import time
from datetime import datetime


class LogLevel:
    EXT      = 3
    DETAIL   = 5
    DEBUG    = 10
    INFO     = 20
    NOTICE   = 25
    WARNING  = 30
    ERROR    = 40
    CRITICAL = 50
    PANIC    = 60

log_level_names = {
    LogLevel.EXT:      "EXT",
    LogLevel.DETAIL:   "DETAIL",
    LogLevel.DEBUG:    "DEBUG",
    LogLevel.INFO:     "INFO",
    LogLevel.NOTICE:   "NOTICE",
    LogLevel.WARNING:  "WARNING",
    LogLevel.ERROR:    "ERROR",
    LogLevel.CRITICAL: "CRITICAL",
    LogLevel.PANIC:    "PANIC",
}

for lvl, name in log_level_names.items():
    logging.addLevelName(lvl, name)


class LogConfigs(logging.Logger):
    def ext(self, msg, *args, **kwargs):
        if self.isEnabledFor(LogLevel.EXT):
            self._log(LogLevel.EXT, msg, args, **kwargs)

    def detail(self, msg, *args, **kwargs):
        if self.isEnabledFor(LogLevel.DETAIL):
            self._log(LogLevel.DETAIL, msg, args, **kwargs)

    def notice(self, msg, *args, **kwargs):
        if self.isEnabledFor(LogLevel.NOTICE):
            self._log(LogLevel.NOTICE, msg, args, **kwargs)

    def panic(self, msg, *args, **kwargs):
        self._log(LogLevel.PANIC, msg, args, **kwargs)


logging.setLoggerClass(LogConfigs)

logger_obj = None


def init_logger(log_level=None,
                enable_file_logging=False,
                module_name=None,
                folder_name=None,
                log_file_max_size=None,
                max_log_files=None):
    global logger_obj

    # -- Defaults -------------------------------------------------------------
    if log_level is None:
        log_level = logging.DEBUG

    if module_name is None or module_name == "":
        module_name = "belog"

    if folder_name is None or folder_name == "":
        folder_name = "be"

    if max_log_files is None or max_log_files == "":
        max_log_files = 5

    if log_file_max_size is None or log_file_max_size == "":
        log_file_max_size = 10 * 1024 * 1024

    # -- Resolve enable_file_logging ------------------------------------------
    if not enable_file_logging:
        enable_file_logging = False
    elif isinstance(enable_file_logging, str):
        if enable_file_logging.lower() == "yes" or enable_file_logging.lower() == "true":
            enable_file_logging = True
        elif enable_file_logging.lower() == "no" or enable_file_logging.lower() == "false":
            enable_file_logging = False
        else:
            enable_file_logging = False

    # -- Get or create logger -------------------------------------------------
    logger = logging.getLogger(module_name)

    if logger.handlers:
        logger.info("Logger already initialized. Skipping reinitialization.")
        logger_obj = logger
        return

    logger.setLevel(log_level)
    logger.propagate = False

    # -- Console handler always added -----------------------------------------
    formatter = logging.Formatter(fmt='%(asctime)s %(levelname)s: %(message)s')
    ch = logging.StreamHandler()
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    # -- Store config on logger for configure_file_logger to use later --------
    logger._module_name       = module_name
    logger._folder_name       = folder_name
    logger._log_file_max_size = log_file_max_size
    logger._max_log_files     = max_log_files

    # -- File handler only if explicitly enabled ------------------------------
    if enable_file_logging:
        try:
            _base   = os.path.dirname(os.path.abspath(__file__))
            log_dir = os.path.join(_base, "../../logs", folder_name)
            os.makedirs(log_dir, exist_ok=True)
        except Exception as e:
            print("Failed to create log directory: {}".format(e))
            raise

        try:
            log_path = os.path.join(log_dir, "{}.log".format(module_name))
            fh = RotatingFileHandler(
                log_path,
                maxBytes    = log_file_max_size,
                backupCount = max_log_files
            )
            fh.setFormatter(formatter)
            logger.addHandler(fh)
        except Exception as e:
            print("Failed to add file handler: {}".format(e))

    logger_obj = logger
    logger.info("Logger initiated with log level:{}, file logging:{}".format(
        log_level_names.get(log_level), enable_file_logging))

def _get_level_name(level):
    if isinstance(level, int):
        return log_level_names.get(level, str(level))
    return str(level)

def configure_file_logger(log_level=None, enable_file_logging=False):
    global logger_obj

    if logger_obj is None:
        print("Logger not initialized yet. Call init_logger() first.")
        return

    logger = logging.getLogger(logger_obj.name)

    # -- Update log level if provided -----------------------------------------
    if log_level is not None:
        if isinstance(log_level, str):
            level_map = {v: k for k, v in log_level_names.items()}
            log_level = level_map.get(log_level.upper(), logging.DEBUG)

        if isinstance(log_level, int):
            logger.setLevel(log_level)
            for h in logger.handlers:
                h.setLevel(log_level)

    # -- Resolve enable_file_logging ------------------------------------------
    if not enable_file_logging:
        enable_file_logging = False
    elif isinstance(enable_file_logging, str):
        if enable_file_logging.lower() == "yes" or enable_file_logging.lower() == "true":
            enable_file_logging = True
        elif enable_file_logging.lower() == "no" or enable_file_logging.lower() == "false":
            enable_file_logging = False
        else:
            enable_file_logging = False

    # -- Check if file handler already exists ---------------------------------
    has_file_handler = any(
        isinstance(h, RotatingFileHandler) for h in logger.handlers
    )

    # -- Add file handler if enabled and not already present ------------------
    if enable_file_logging and not has_file_handler:
        module_name       = getattr(logger, '_module_name',       logger.name)
        folder_name       = getattr(logger, '_folder_name',       logger.name)
        log_file_max_size = getattr(logger, '_log_file_max_size', 10 * 1024 * 1024)
        max_log_files     = getattr(logger, '_max_log_files',     5)

        try:
            _base   = os.path.dirname(os.path.abspath(__file__))
            log_dir = os.path.join(_base, "../../logs", folder_name)
            os.makedirs(log_dir, exist_ok=True)
        except Exception as e:
            print("Failed to create log directory: {}".format(e))
            return

        try:
            log_path = os.path.join(log_dir, "{}.log".format(module_name))
            fh = RotatingFileHandler(
                log_path,
                maxBytes    = log_file_max_size,
                backupCount = max_log_files
            )
            fh.setFormatter(logging.Formatter(fmt='%(asctime)s %(levelname)s: %(message)s'))
            logger.addHandler(fh)
            logger.info("File logging enabled at {}".format(log_path))
        except Exception as e:
            print("Failed to add file handler: {}".format(e))

    # -- Remove file handler if disabled and present --------------------------
    elif not enable_file_logging and has_file_handler:
        for h in logger.handlers:
            if isinstance(h, RotatingFileHandler):
                h.close()
                logger.removeHandler(h)
        logger.info("File logging disabled")


def set_log_level(log_level):
    if logger_obj is None:
        print("Logger is not initialized. Call init_logger() first.")
        return

    try:
        logger_obj.setLevel(log_level)
        for handler in logger_obj.handlers:
            handler.setLevel(log_level)
        logger_obj.info("Log level changed to {}".format(log_level))
    except Exception as e:
        logger_obj.error("Failed to update the log level, Exception occurred")
        logger_obj.error("Exception error msg: {}".format(str(e)))


def shutdown_logger():
    logging.shutdown()

'''
def init_logger(log_level=None, enable_file_logging=None,
                module_name=None, folder_name=None,
                log_file_max_size=None, max_log_files=None):
    global logger_obj

    if log_level is None:
        log_level = logging.DEBUG

    logger = logging.getLogger(module_name or "app")
    if logger.handlers:
        logger_obj = logger
        return

    logger.setLevel(log_level)
    logger.propagate = False

    formatter = logging.Formatter(fmt='%(asctime)s %(levelname)s: %(message)s')
    import sys as _sys, io as _io
    if _sys.platform == 'win32':
        _utf8 = _io.TextIOWrapper(_sys.stdout.buffer, encoding='utf-8', errors='replace')
        ch = logging.StreamHandler(_utf8)
    else:
        ch = logging.StreamHandler()
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    module_name   = module_name   or "belog"
    folder_name   = folder_name   or "be"
    max_log_files = max_log_files or 5
    log_file_max_size = log_file_max_size or (10 * 1024 * 1024)

    if not enable_file_logging:
        enable_file_logging = False
    elif isinstance(enable_file_logging, str):
        enable_file_logging = enable_file_logging.lower() == "yes"

    log_dir = f"../logs/{folder_name}"
    try:
        os.makedirs(log_dir, exist_ok=True)
    except Exception as e:
        print(f"Failed to create log directory: {e}")

    log_path = os.path.join(log_dir, f"{module_name}.log")
    fh = RotatingFileHandler(log_path, maxBytes=log_file_max_size, backupCount=max_log_files)
    fh.setFormatter(formatter)
    fh.disabled = not enable_file_logging
    logger.addHandler(fh)

    logger_obj = logger
    logger.info(f"Logger initiated — level:{log_level_names.get(log_level)}, file:{enable_file_logging}")
'''


'''
def configure_file_logger(log_level=None, enable_file_logging=False):
    global logger_obj
    if logger_obj is None:
        return
    logger = logging.getLogger(logger_obj.name)
    if isinstance(log_level, str):
        level_map = {v: k for k, v in log_level_names.items()}
        log_level = level_map.get(log_level.upper(), logging.DEBUG)
        logger.setLevel(log_level)
        for h in logger.handlers:
            h.setLevel(log_level)
    if isinstance(enable_file_logging, str):
        enable_file_logging = enable_file_logging.lower() == "yes"
    for handler in logger.handlers:
        if isinstance(handler, RotatingFileHandler):
            handler.disabled = not enable_file_logging

'''



def _fmt(message, data=None):
    s = str(message)[:5000]
    if data is not None:
        s += str(data)[:5000]
    return s


def log_ext(msg, data=None):      logger_obj.ext(_fmt(msg, data))
def log_detail(msg, data=None):   logger_obj.detail(_fmt(msg, data))
def log_debug(msg, data=None):    logger_obj.debug(_fmt(msg, data))
def log_info(msg, data=None):     logger_obj.info(_fmt(msg, data))
def log_notice(msg, data=None):   logger_obj.notice(_fmt(msg, data))
def log_warning(msg, data=None):  logger_obj.warning(_fmt(msg, data))
def log_error(msg, data=None):    logger_obj.error(_fmt(msg, data))
def log_critical(msg, data=None): logger_obj.critical(_fmt(msg, data))
def log_panic(msg, data=None):    logger_obj.panic(_fmt(msg, data))
