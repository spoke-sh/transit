"""Sample-app value conversion for existing Python orchestration fixtures.

Protocol/caller conformance is tested by Zig programs. These helpers keep the
counter assertions readable while transmitting v2 opaque bytes on the wire.
"""
import copy


def encode_command(command, revision=0):
    command = copy.deepcopy(command)
    name, body = next(iter(command.items()))
    if not isinstance(body, dict):
        return command
    for field in {"spawn": ("initial_state",), "send": ("value",),
                  "turn": ("result", "effect"), "observe": ("result",)}.get(name, ()):
        if isinstance(body.get(field), int):
            body[field] = str(body[field]).encode().hex()
    if name == "turn":
        body.setdefault("expected_revision", revision)
        for output in body.get("outputs", []):
            if output is not None and isinstance(output["value"], int):
                output["value"] = str(output["value"]).encode().hex()
    return command


def decode_view(view):
    def number(value):
        if value is None:
            return None
        try:
            return int(bytes.fromhex(value).decode() or "0")
        except (ValueError, UnicodeDecodeError):
            return value  # Deliberately malformed sample-app input stays opaque.
    if not isinstance(view, dict) or "process" not in view:
        return view
    view["process"]["state"] = number(view["process"]["state"])
    if view.get("input"):
        view["input"]["value"] = number(view["input"]["value"])
    for effect in view.get("effects", []):
        if effect:
            effect["payload"] = number(effect["payload"])
            effect["result"] = number(effect["result"])
    return view
