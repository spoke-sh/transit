"""Explicit development listener settings, independent of durable realm identity."""
import ipaddress
import os
import re
from urllib.parse import urlsplit


def observability(previous, profile, services=None):
    result = {}
    for service in services or (("board", "node", "maintenance", "delivery", "counter") + (("controller",) if profile == "reference" else ())):
        values = {}
        for field, default, allowed in (("level", "info", ("debug", "info", "warn", "error", "err", "off")),
                                         ("format", "text" if profile == "local" else "json", ("text", "json"))):
            value = os.environ.get(f"REY_{service.upper().replace('-', '_')}_LOG_{field.upper()}",
                    os.environ.get(f"REY_LOG_{field.upper()}", previous.get(service, {}).get(field, default)))
            if value not in allowed:
                raise ValueError(f"Invalid {service} log {field}")
            values[field] = value
        result[service] = values
    return result


def boolean(value):
    if value in ("true", "1"):
        return True
    if value in ("false", "0"):
        return False
    raise ValueError("REY_BOARD_ALLOW_INSECURE_HTTP must be true or false")


def environment():
    result = {}
    for field, name in (("host", "REY_BOARD_HOST"), ("port", "REY_BOARD_PORT"),
                        ("public_origin", "REY_BOARD_PUBLIC_ORIGIN"),
                        ("allow_insecure_http", "REY_BOARD_ALLOW_INSECURE_HTTP")):
        if name in os.environ:
            value = os.environ[name]
            result[field] = int(value) if field == "port" else boolean(value) if field == "allow_insecure_http" else value
    return result


def defaults(base_port):
    return {"host": "127.0.0.1", "port": base_port + 2,
            "public_origin": f"http://127.0.0.1:{base_port + 2}", "allow_insecure_http": False}


def resolve(previous, overrides, base_port):
    settings = {**previous, **overrides}
    try:
        settings["host"] = str(ipaddress.IPv4Address(settings["host"]))
    except ipaddress.AddressValueError as error:
        raise ValueError("REY_BOARD_HOST must be an IPv4 listen address, e.g. 0.0.0.0") from error
    port = settings["port"]
    if type(port) is not int or not 1 <= port <= 65535 or port in (base_port, base_port + 1):
        raise ValueError("Board port must be 1–65535 and distinct from Ursula/Transit ports")
    if "public_origin" not in overrides and previous["public_origin"] == f'http://127.0.0.1:{previous["port"]}':
        settings["public_origin"] = f"http://127.0.0.1:{port}"
    origin = settings["public_origin"]
    # Match an exact browser origin, never a credential, path, wildcard host,
    # control character or a permissive Host/Origin allow-list.
    if not re.fullmatch(r"https?://[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?(?::[0-9]{1,5})?", origin):
        raise ValueError("REY_BOARD_PUBLIC_ORIGIN must be an exact lowercase http(s)://host[:port] origin")
    parsed = urlsplit(origin)
    if len(parsed.netloc) > 200 or parsed.hostname == "0.0.0.0" or parsed.port == 0:
        raise ValueError("Board public origin must identify a reachable host, not a wildcard listener")
    if parsed.scheme == "http" and not (parsed.hostname == "127.0.0.1" and parsed.port is not None) and not settings["allow_insecure_http"]:
        raise ValueError("Remote development HTTP requires REY_BOARD_ALLOW_INSECURE_HTTP=true; use HTTPS otherwise")
    return settings
