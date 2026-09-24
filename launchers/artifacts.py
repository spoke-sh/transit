"""Identified candidates and selected artifacts; neither grants execution rights."""
import hashlib
import json
import os
from pathlib import Path
import shutil

from common import ROOT, run, write

ROLES = {"node": "transit-node", "maintenance": "transit-node", "delivery": "transit-delivery", "counter": "example-counter",
         "board": "transit-board", "controller": "transit-runtime-controller"}


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


class Artifacts:
    def __init__(self, installation):
        self.installation = installation
        self.path = ROOT / ".cache/launcher-artifacts" / installation.profile / installation.name

    def read(self, kind):
        file = self.path / (kind + ".json")
        return json.loads(file.read_text()) if file.exists() else {}

    def roles(self, names):
        available = [r for r in ROLES if r != "controller" or self.installation.profile == "reference"]
        names = names or available
        if set(names) - set(available):
            raise ValueError("Build/update services: " + ", ".join(available))
        # A shared executable is deployed consistently across its service roles.
        artifacts = {ROLES[name] for name in names}
        return [r for r in available if ROLES[r] in artifacts]

    def native(self, names, target=None):
        prefix = self.path / ("build-" + (target or "native"))
        argv = ["zig", "build", *sorted(set(names)), "-Doptimize=ReleaseSafe", "--prefix", prefix]
        if target:
            argv.append("-Dtarget=" + target)
        run(argv, cwd=ROOT, timeout=900)
        result = {}
        for name in set(names):
            source = prefix / "bin" / name
            sha = digest(source)
            destination = self.path / "objects" / sha / name
            if not destination.exists():
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
                destination.chmod(0o555)
            result[name] = {"sha256": sha, "path": str(destination), "target": target or "native"}
        return result

    def build(self, names=None):
        roles = self.roles(names)
        names = sorted({ROLES[r] for r in roles})
        print("Building: " + ", ".join(roles), flush=True)
        candidates = self.read("candidates")
        helper_names = []
        if "tools/rey-cli" not in candidates or any(r in roles for r in ("node", "counter", "controller")):
            helper_names.append("rey-cli")
        if self.installation.profile != "local" and ("tools/transit-node" not in candidates or "node" in roles):
            helper_names.append("transit-node")
        helpers = self.native(helper_names) if helper_names else {}
        candidates.update({"tools/" + name: value for name, value in helpers.items()})
        target = None
        if self.installation.profile != "local":
            architecture = run(["docker", "info", "--format", "{{.Architecture}}"], capture=True).strip()
            target = {"x86_64": "x86_64-linux-musl", "aarch64": "aarch64-linux-musl"}.get(architecture)
            if target is None:
                raise RuntimeError("Application images require a Linux x86_64 or aarch64 Docker engine")
        built = self.native(names, target)
        for name, artifact in built.items():
            if target:
                context = self.path / "images" / name
                context.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(artifact["path"], context / name)
                (context / name).chmod(0o755)
                # Reference controller packaging adds the pinned provider client.
                if name == "transit-runtime-controller":
                    artifact["image"] = self.controller_image(context, artifact)
                else:
                    write(context / "Dockerfile", f'FROM scratch\nCOPY {name} /bin/{name}\nUSER 65532:65532\nENTRYPOINT ["/bin/{name}"]\n')
                    iid = context / "image.id"
                    run(["docker", "build", "--iidfile", iid, context], timeout=300)
                    artifact["image"] = iid.read_text().strip()
            candidates[name] = artifact
        provenance = {"commit": run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture=True).strip(),
                      "dirty": bool(run(["git", "status", "--porcelain"], cwd=ROOT, capture=True)),
                      "zig": run(["zig", "version"], capture=True).strip(),
                      "flake_lock": digest(ROOT / "flake.lock"), "optimize": "ReleaseSafe"}
        candidates["provenance"] = provenance
        write(self.path / "candidates.json", candidates)
        return candidates

    def controller_image(self, context, artifact):
        # Nix's closure supplies the CLI and its loader on the target platform.
        # The controller itself is static; external CLI remains upstream Go.
        outputs = json.loads(run(["nix", "build", ".#kubectl-ate", "--no-link", "--json"], cwd=ROOT, capture=True, timeout=900))
        package = outputs[0]["outputs"]["out"]
        closure = run(["nix-store", "--query", "--requisites", package], capture=True).splitlines()
        for entry in closure:
            destination = context / entry.lstrip("/")
            if not destination.exists():
                shutil.copytree(entry, destination, symlinks=True)
        (context / "nix").chmod(0o755)
        (context / "nix/store").chmod(0o755)
        write(context / "Dockerfile", 'FROM scratch\nCOPY --chmod=0555 nix /nix\nCOPY transit-runtime-controller /bin/transit-runtime-controller\nUSER 65532:65532\nENTRYPOINT ["/bin/transit-runtime-controller"]\n')
        write(context / "provider.json", {"cli": package + "/bin/kubectl-ate"})
        artifact["provider_cli"] = package + "/bin/kubectl-ate"
        iid = context / "image.id"
        run(["docker", "build", "--iidfile", iid, context], timeout=300)
        return iid.read_text().strip()

    def initialize(self):
        if self.read("selected"):
            if "transit-delivery" not in self.read("selected"):
                raise RuntimeError("Pre-M8 artifacts require a coordinated launcher update without service names; see launchers/README.md")
            return
        candidates = self.build()
        write(self.path / "selected.json", candidates)

    def binary(self, name):
        selected = self.read("selected")
        value = selected.get("tools/" + name) or selected.get(name)
        if value is None:
            raise RuntimeError("No selected artifact; run launcher up first")
        return Path(value["path"])

    def select(self, selection):
        write(self.path / "selected.json", selection)

    def plan(self, names, no_build=False):
        roles = self.roles(names)
        candidates = self.read("candidates") if no_build else self.build(roles)
        selected = self.read("selected")
        target = dict(selected)
        for name in {ROLES[r] for r in roles}:
            if name not in candidates:
                raise RuntimeError(f"No candidate for {name}; run build first")
            target[name] = candidates[name]
        for name, value in candidates.items():
            if name.startswith("tools/") or name == "provenance":
                target[name] = value
        changed = [role for role in roles if target[ROLES[role]] != selected.get(ROLES[role])]
        return target, changed
