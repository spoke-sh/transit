"""Board reads the real two-editor Document without application interpretation."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
from urllib.parse import urlencode
from storage import free_port, wait_ready


class DocumentBoard:
    def __init__(self, system, writer, command, query, write, binaries, browser=False):
        self.system, self.writer, self.command, self.query = system, writer, command, query
        self.write, self.binaries, self.browser = write, binaries, browser
        self.seed, public = system.key("board-document")
        command({"grant": {"subject": 55, "public_key": public, "permissions": 16}})
        self.grant(3)
        port = free_port()
        self.origin = f"http://127.0.0.1:{port}"
        config = write("board-document.json", dict(upstream=system.url, realm=72, principal=55,
            profile="growing_v3", seed_file=str(self.seed), public_origin=self.origin, port=port,
            request_timeout_ms=5000, upstream_timeout_ms=1500))
        self.process = system.start(binaries["transit-board"], config)
        wait_ready(system.store.http, self.process, self.origin + "/health")
        self.path = f'/api/v1/resources/{writer["resource"]}/documents/17'

    def grant(self, permissions):
        self.command({"grant_resource": {"resource": self.writer["resource"], "subject": 55, "permissions": permissions}})

    def request(self, path=None, status=200):
        time.sleep(.15)
        try: response = self.system.store.http.open(self.origin + (path or self.path), timeout=15)
        except urllib.error.HTTPError as error: response = error
        with response:
            data = response.read()
            assert response.status == status, (response.status, data[:200])
            assert response.headers["Cache-Control"] == "no-store"
            for forbidden in (b"Notes", b"Left", b"Right", b"Resolved", "A🙂a".encode()):
                assert forbidden not in data
            return json.loads(data)

    def inspect(self, revision, floor, *, conflicts=0, retired=False):
        before = self.query({"capabilities": {}})["position"]
        page = self.request()
        d = page["declaration"]
        assert d["document"] == "17" and d["revision"] == str(revision) and d["floor"] == str(floor)
        assert d["retired"] == retired and d["change_format"] == 1 and d["type_revision"] == 1
        assert page["source"]["resource"] == self.writer["resource"]
        assert page["source"]["pid"] == self.writer["pid"]
        assert page["source"]["key"] == (b"\0D" + (17).to_bytes(8, "big") + b"h" + bytes(8)).hex()
        if retired:
            assert page["registers"] is None
        else:
            assert page["registers"] == dict(count=5, conflicts=conflicts, assignments=5+conflicts, next=None), page["registers"]
        assert self.query({"capabilities": {}})["position"] == before, "Inspection mutated authority"
        subprocess.run(["node", "tests/board_document_client.mjs"], input=json.dumps(page).encode(), check=True, timeout=20)
        return page

    def prove(self):
        assert self.request("/api/v1/capabilities")["documents"]
        page = self.inspect(3, 0, conflicts=1)
        after = (b"RM" + bytes(16) + b"body").hex()
        cursor = "?" + urlencode(dict(revision=page["source"]["resource_revision"], after=after))
        assert self.request(self.path+cursor)["registers"]["count"] == 1
        self.request(self.path+"?after="+after, 400)
        self.request(self.path+"?revision=0&after="+after, 409)
        self.grant(0)
        assert self.request(status=403)["err"] == "Forbidden"
        self.request(self.path+cursor, 403)
        self.grant(3)
        self.inspect(3, 0, conflicts=1)
        if self.browser:
            sequence = self.query({"capabilities": {}})["principal_sequence"]+1
            paths = [self.write(f"board-{name}.json", dict(realm=72, principal=0, sequence=sequence+i,
                command={"grant_resource": {"resource": self.writer["resource"], "subject": 55, "permissions": permission}}))
                for i, (name, permission) in enumerate((("revoke", 0), ("restore", 3)))]
            env = os.environ | dict(BOARD_TEST_URL=self.origin, BOARD_DOCUMENT_RESOURCE=str(self.writer["resource"]),
                BOARD_DOCUMENT_CLI=str(self.binaries["rey-cli"]), BOARD_DOCUMENT_SEED=str(self.system.seed),
                BOARD_DOCUMENT_AUTHORITY=self.system.url, BOARD_DOCUMENT_REVOKE=str(paths[0]), BOARD_DOCUMENT_RESTORE=str(paths[1]))
            try:
                subprocess.run(["vp", "exec", "--filter", "@rey/transit-board-web", "playwright", "test", "document.spec.ts"], env=env, check=True, timeout=120)
            finally:
                self.grant(3)
        print("Document Board: accepted metadata, exact cuts, generated validation and revoked continuation passed" + (" with browser clearing" if self.browser else ""), flush=True)

    def close(self):
        self.process.kill()
        self.process.wait(timeout=10)
