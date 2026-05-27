"""
backend_config.py - Configuration loader and validator
"""

import copy
from backend_utils import *
from backend_logger import *


class BackendConfig:
    def __init__(self):
        self.config_init_done    = False
        self.backend_json_config = None
        self.config_file_path    = None
        self.fastapi_config      = None
        self.logger_config       = None
        self.certs_config        = {}
        self.ipc_script_running_lock = allocate_lock()

    def get_ipc_script_running_lock(self):  
        self.ipc_script_running_lock.acquire()
    
    def give_ipc_script_running_lock(self): 
        self.ipc_script_running_lock.release()

    def config_load_and_init(self, be_config_file="../config/backend_ipc_config.json"):
        log_debug("Backend config init in progress")

        status, be_jconfig = self._load_config(be_config_file)
        if not status:
            return False, be_jconfig

        status, msg = self._validate_be_config(be_jconfig)
        if not status:
            return False, msg

        status, logger_config = self.generate_logger_config(be_jconfig)
        if status != True:
            return status, "Failed"

        self.config_file_path = os.path.abspath(be_config_file)
        self.backend_json_config = be_jconfig
        self.logger_config       = logger_config
        self.fastapi_config      = copy.deepcopy(be_jconfig.get("fastapi", {}))
        self.certs_config        = copy.deepcopy(be_jconfig.get("certs", {}))

        log_level    = self.logger_config.get("logging_level", "DEBUG")
        file_logging = self.logger_config.get("file_logging", "No")

        set_log_level(log_level)
        configure_file_logger(log_level=log_level, enable_file_logging=file_logging)

        self.config_init_done = True
        log_info("Backend config loaded successfully")
        return True, "Config load and init Successful"

    def _load_config(self, config_file):
        if string_none_or_empty(config_file):
            return False, "Config file path not provided"
        return read_config_file(config_file)

    def _validate_be_config(self, cfg):
        required = ["name", "type", "timezone", "fastapi", "logger_config", "certs"]
        for key in required:
            if key not in cfg:
                log_error(f"Missing required config key: {key}")
                return False, f"Missing key: {key}"

        if "logger_config" in cfg.keys():
            status, sts_msg = self.validate_logger_config(cfg['logger_config'],"Backend Logger")
            if status != True:
                log_error("Backend validate logger config failed")
                return False, sts_msg

        if "fastapi" in cfg.keys():
            status, sts_msg = self.validate_fastapi_config(cfg['fastapi'], "Fastapi")
            if status != True:
                log_error("Backend validate fastapi config failed")
                return False, sts_msg

        return True, "Success"

    def validate_config_keys(self,
                             mandatory_keys: list,
                             config_json,
                             name :str,
                             check_empty: bool = True,
                            ):
        config_keys = config_json.keys()
        for mkey in mandatory_keys:
            if mkey not in config_keys:
                log_debug("Config Json {}:{}".format(name, config_json))
                log_error("Mandatory key {} not present in {}".format(
                            mkey, config_keys ))
                return False, "Key {} not Present".format(mkey)

            if check_empty:
                if isinstance(config_json[mkey], str):
                    if string_none_or_empty(config_json[mkey]):
                        log_error("Mandatory key {} value empty".format(mkey))
                        return False, "Value for {} field is empty".format(mkey)

        return True, "Success"

    def validate_fastapi_config(self, fapi_config, parent : str):
        mandatory_keys = ['enable', 'host', 'domain_names', 'security']
        status, sts_msg = self.validate_config_keys(mandatory_keys,
                                                    fapi_config,
                                                    "Backend Fast Api Config"
                                                    )
        if status != True:
            log_msg = "Validate Fast api config under {} Failed".format(parent)
            log_error(log_msg)
            return False, log_msg
        
        if 'security' in fapi_config and fapi_config['security']['enable'].lower() == "yes":
            if not isinstance(fapi_config['security'], dict):
                log_msg = "Security config  under {} must be a dict".format(parent)
                log_error(log_msg)
                return False, log_msg

            status, log_msg = self.validate_fastapi_security_config(
                                                    fapi_config['security'],
                                                    "Backend Fastapi Security Config"
                                                    )
            if status != True:
                log_error("Validate Fastapi security config under {} Failed".format(parent))
                return False, log_msg

        return True, "Success"

    def validate_fastapi_security_config(self, fapi_sec_config, parent: str):
        mandatory_fields = ['enable', 'type', 'ca_file', 'cert_file', 'key_file']

        status, log_msg = self.validate_config_keys(mandatory_fields,
                                                    fapi_sec_config,
                                                    "Backend Fastapi Security Config"
                                                    )
        if status != True:
            return status, log_msg

        return True, "Success"

    def validate_logger_config(self, logger_config, parent:str):
        mandatory_fields = ["logging_level" , "file_logging"]
        
        status, log_msg = self.validate_config_keys(mandatory_fields,
                                                    logger_config,
                                                    "Backend Logger Config"
                                                    )
        if status != True:
            return status, log_msg
        
        return True, "Success"

    def generate_logger_config(self, be_config):
        log_debug("Generate Logger config from Devctl json config")
        logger_config = copy.deepcopy(be_config['logger_config'])
        return True, logger_config

    def get_fastapi_config(self):
        if not self.config_init_done:
            return False, "Config not initialised"
        return True, copy.deepcopy(self.fastapi_config)

    def get_ca_cert_path(self):
        if not self.config_init_done:
            return False, "Config not initialised"
        path = self.certs_config.get("ca_cert_path", "/etc/mosquitto/certs/ca.crt")
        return True, path
