"""Source orchestration using the existing shared SDK host; no CLI or wire signer."""
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile


class ClientError(RuntimeError):
    def __init__(self, status, detail):
        self.status, self.detail = status, detail
        super().__init__(f"Native client status {status}: {detail}")

    @property
    def retryable_read(self):
        # The host preserves the native capacity cause under query status 7.
        return self.status == 7 and isinstance(self.detail, dict) and self.detail.get("err") in (
            "AuthorityUnavailable", "AuthorityTimeout", "HttpConnectionClosing", "ConnectionRefused", "HttpCapacity")


def private_seed(path):
    path = Path(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError("Seed must be an owner-only regular file")
    seed = bytes.fromhex(path.read_text().strip())
    if len(seed) != 32:
        raise ValueError("Seed must contain 32 hexadecimal bytes")
    return seed


def public_key(path):
    # RFC 8410 PKCS#8/SPKI containers. OpenSSL derives the Ed25519 public key;
    # Transit signing and validation remain in the shared client implementation.
    seed = private_seed(path)
    result = subprocess.run(["openssl", "pkey", "-inform", "DER", "-pubout", "-outform", "DER"],
        input=bytes.fromhex("302e020100300506032b657004220420") + seed,
        capture_output=True, check=True, timeout=10).stdout
    if len(result) != 44 or result[:12] != bytes.fromhex("302a300506032b6570032100"):
        raise RuntimeError("Invalid Ed25519 public key")
    return list(result[12:])


class Client:
    def __init__(self, host, url):
        self.host, self.url = host, url

    def request(self, message):
        with tempfile.TemporaryDirectory(prefix="transit-client-") as directory:
            config = Path(directory) / "config.json"
            config.write_text(json.dumps({"url": self.url, "timeout_ms": 5000}))
            result = subprocess.run([str(self.host), str(config)], input=json.dumps(message) + "\n",
                text=True, capture_output=True, check=True, timeout=10)
        if len(result.stdout) > 1024 * 1024:
            raise RuntimeError("Client host response exceeded its bound")
        response = json.loads(result.stdout)
        if not isinstance(response, dict) or set(response) != {"status", "value"} or type(response["status"]) is not int:
            raise RuntimeError("Invalid client host response")
        if response["status"] != 0:
            raise ClientError(response["status"], response["value"])
        return response["value"]

    def prepare(self, seed, document, *, query=False):
        private_seed(seed)
        frozen = self.request({"prepare": {"kind": 7 if query else 6,
            "seed_file": str(Path(seed).resolve()), "document": json.dumps(document)}})
        if not isinstance(frozen, str):
            raise RuntimeError("Invalid frozen operation")
        return frozen

    def call(self, frozen):
        return self.request({"call": frozen})

    def query(self, seed, document):
        return self.call(self.prepare(seed, document, query=True))

    def submit(self, seed, document):
        return self.call(self.prepare(seed, document))
