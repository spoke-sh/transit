"""Automatic private run records and bounded, streaming command diagnostics."""
from collections import deque
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

LOG_LIMIT = 16 * 1024 * 1024


def provenance(root):
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root,
                              capture_output=True, text=True)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=root,
                            capture_output=True, text=True)
    lock = root / "flake.lock"
    return {"revision": revision.stdout.strip() or None,
            "dirty": bool(status.stdout) if status.returncode == 0 else None,
            "toolchain": {
                "flake_lock_sha256": hashlib.sha256(lock.read_bytes()).hexdigest() if lock.exists() else None,
                "python_version": sys.version,
                "executables": {name: str(Path(path).resolve()) if path else None
                                for name, path in (("python", sys.executable),
                                                   *((name, shutil.which(name)) for name in ("nix", "zig", "just")))}}}


def directory(destination):
    runs = destination.parent / "runs"
    runs.mkdir(parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix=destination.stem + "-", dir=runs))


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def identity(path):
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    return {"path": path.name, "bytes": path.stat().st_size, "sha256": digest}


def verify(directory):
    """A copied/uploaded record needs its exact artifacts and every task result."""
    if (directory / "report.json").exists():
        report = json.loads((directory / "report.json").read_text())
        assert report["completed"] and report["active"] is None, "incomplete check run"
        assert [row["id"] for row in report["checks"]] == report["expected_checks"]
        assert all(row["completed"] and [stage["stage"] for stage in row["stages"]] == row["expected_stages"]
                   for row in report["checks"])
        stages = [stage for row in report["checks"] for stage in row["stages"]]
    else:
        report = json.loads((directory / "meta.json").read_text())
        assert report["completed"] and report["active_task"] is None, "incomplete CI run"
        stages = json.loads((directory / "results.json").read_text())
        assert [row["task"] for row in stages] == report["expected_tasks"]
        assert report["result_count"] == len(stages)
    assert stages, "no executed stages"
    for stage in stages:
        assert stage["completed"] and stage["exit_code"] == 0, stage
        for artifact in (stage["diagnostics"]["artifact"], *([stage["stdout"]] if "stdout" in stage else [])):
            assert Path(artifact["path"]).name == artifact["path"], artifact
            assert identity(directory / artifact["path"]) == artifact, artifact


class Log:
    """Keep the beginning and end; stream all output to the caller's console."""
    def __init__(self, output, limit):
        assert limit > 1
        self.output = output
        self.head_limit = limit // 2
        self.tail_limit = limit - self.head_limit
        self.total = self.head = self.tail_size = 0
        self.tail = deque()

    def write(self, data):
        self.total += len(data)
        prefix = data[:max(0, self.head_limit - self.head)]
        self.output.write(prefix)
        self.head += len(prefix)
        rest = data[len(prefix):]
        if rest:
            self.tail.append(rest)
            self.tail_size += len(rest)
        while self.tail_size > self.tail_limit:
            chunk = self.tail.popleft()
            discard = min(len(chunk), self.tail_size - self.tail_limit)
            self.tail_size -= discard
            if discard < len(chunk):
                self.tail.appendleft(chunk[discard:])

    def finish(self):
        omitted = self.total - self.head - self.tail_size
        if omitted:
            self.output.write(f"\n[runner omitted {omitted} diagnostic bytes; beginning and end retained]\n".encode())
        for chunk in self.tail:
            self.output.write(chunk)
        return {"bytes": self.total, "retained_bytes": self.head + self.tail_size,
                "omitted_bytes": omitted}


def run(command, *, cwd, log, result, input=None, capture_stdout=False,
        console=None, limit=LOG_LIMIT, env=None):
    """Retain diagnostic bytes even on failure; never truncate semantic stdout.

    The enclosing runner checkpoints result/log names before launch. SIGKILL or
    job cancellation may prevent finalization, so absence of `completed` remains
    incomplete. Children stay in the caller's process group for job cancellation.
    """
    result.update(command=command, log=log.name, completed=False, exit_code=None)
    if console is None:
        console = sys.stderr if capture_stdout else sys.stdout
    console = getattr(console, "buffer", console)
    with log.open("wb", buffering=0) as output, tempfile.TemporaryFile() as stdin:
        retained = Log(output, limit)
        if input is not None:
            stdin.write(input)
            stdin.seek(0)
        # Contract generator output is an executable input, not a diagnostic log.
        # Store the exact bytes separately, without console decoration/truncation.
        generated = log.with_suffix(".stdout") if capture_stdout else None
        semantic = generated.open("w+b") if generated else None
        process = None
        try:
            process = subprocess.Popen(command, cwd=cwd, env=env,
                                       stdin=stdin if input is not None else None,
                                       stdout=semantic if semantic else subprocess.PIPE,
                                       stderr=subprocess.PIPE if semantic else subprocess.STDOUT)
            result["pid"] = process.pid
            stream = process.stderr if semantic else process.stdout
            with stream:
                while data := stream.read1(65536):
                    retained.write(data)
                    if hasattr(console, "encoding"):
                        console.write(data.decode(console.encoding or "utf-8", errors="replace"))
                    else:
                        console.write(data)
                    console.flush()
            code = process.wait()
            result.update(exit_code=code, completed=True)
            body = None
            if semantic:
                semantic.flush()
                semantic.seek(0)
                body = semantic.read()
                result["stdout"] = {"path": generated.name, "bytes": len(body),
                                    "sha256": hashlib.sha256(body).hexdigest()}
            return subprocess.CompletedProcess(command, code, stdout=body)
        except BaseException as error:
            result["error"] = type(error).__name__
            if process is not None:
                process.kill()
                process.wait()
                result["exit_code"] = process.returncode
            raise
        finally:
            result["diagnostics"] = retained.finish()
            result["diagnostics"]["artifact"] = identity(log)
            if semantic:
                semantic.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Verify completion and exact artifacts in an automatic run record.")
    parser.add_argument("directory", type=Path)
    verify(parser.parse_args().directory)
    print("Complete run record: task outcomes and artifacts verified.")
