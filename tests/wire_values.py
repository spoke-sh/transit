"""Sample-app value conversion for existing Python orchestration fixtures.

Protocol/caller conformance is tested by Zig programs. These helpers keep the
counter assertions readable while transmitting native v1 opaque bytes on the wire.
"""
import copy


def encode_command(command, revision=0):
    command = copy.deepcopy(command)
    name, body = next(iter(command.items()))
    if not isinstance(body, dict):
        return command
    for field in {"send": ("value",), "turn": ("effect",),
                  "observe": ("result",)}.get(name, ()):
        if isinstance(body.get(field), int):
            body[field] = str(body[field]).encode().hex()
    if name == "turn":
        body.setdefault("expected_revision", revision)
        for output in body.get("outputs", []):
            if output is not None and isinstance(output["value"], int):
                output["value"] = str(output["value"]).encode().hex()
    return command
