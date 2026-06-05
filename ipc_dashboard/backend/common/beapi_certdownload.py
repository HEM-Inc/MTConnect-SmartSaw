"""
beapi_certdownload.py - Certificate download business logic (OpenSSL-free, subject as string)
"""
import os
from datetime import datetime, timezone
from backend_logger import *

from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.x509.oid import NameOID


class BackendCertDownloadApi:

    def _parse_issuer(self, name):
        """
        Convert cryptography.x509.Name object to dict (C, ST, L, O, OU)
        """
        mapping = {
            NameOID.COUNTRY_NAME: "Country",
            NameOID.STATE_OR_PROVINCE_NAME: "State",
            NameOID.LOCALITY_NAME: "Locality",
            NameOID.ORGANIZATION_NAME: "Organization",
            NameOID.ORGANIZATIONAL_UNIT_NAME: "Organizational Unit"
        }

        result = {}
        for attr in name:
            key = mapping.get(attr.oid)
            if key:
                result[key] = attr.value
        return result

    def _format_name_str(self, name):
        """
        Convert cryptography.x509.Name object to a string like:
        'C = US, ST = OK, L = PR, O = HM, OU = IIOT'
        """
        return ", ".join(f"{attr.oid._name} = {attr.value}" for attr in name)

    def get_ca_cert_path(self):
        if not getattr(self, "config_init_done", False):
            return False, "Config not inited"
        return self.config.get_ca_cert_path()

    def get_ca_cert_info(self):
        if not getattr(self, "config_init_done", False):
            return False, "Config not inited"

        status, cert_path = self.get_ca_cert_path()
        if status is not True:
            return False, cert_path

        if not os.path.exists(cert_path):
            log_error(f"Certificate not found at {cert_path}")
            return False, "Certificate not found"

        try:
            stat = os.stat(cert_path)
            size_bytes = stat.st_size
            mtime = datetime.fromtimestamp(stat.st_mtime).isoformat()

            with open(cert_path, "rb") as f:
                cert_data = f.read()

            cert = x509.load_pem_x509_certificate(cert_data, default_backend())

            # Subject as string
            subject_str = self._format_name_str(cert.subject)

            # Issuer as parsed dict
            issuer_dict = self._parse_issuer(cert.issuer)

            # Validity
            not_before = cert.not_valid_before_utc.strftime("%b %d %H:%M:%S %Y GMT")
            not_after  = cert.not_valid_after_utc.strftime("%b %d %H:%M:%S %Y GMT")

            # Expiry info
            now = datetime.now(timezone.utc)
            delta = cert.not_valid_after_utc - now
            is_expired = delta.days < 0
            days_remaining = max(delta.days, 0) if not is_expired else 0

            cert_details = {
                "subject": subject_str,
                "issuer": issuer_dict,
                "notBefore": not_before,
                "notAfter": not_after,
            }

            info = {
                "path": cert_path,
                "filename": os.path.basename(cert_path),
                "file_size_bytes": size_bytes,
                "file_size_kb": round(size_bytes / 1024, 2),
                "last_modified": mtime,
                "cert_details": cert_details,
                "available": True,
                "expiry_date": cert.not_valid_after_utc.isoformat(),
                "is_expired": is_expired,
                "days_remaining": days_remaining,
            }

            log_info(f"Cert info fetched: expiry {cert.not_valid_after_utc.isoformat()}, days_remaining: {days_remaining}, expired: {is_expired}")
            return True, info

        except Exception as e:
            log_error(f"get_ca_cert_info exception: {str(e)}")
            return False, str(e)
