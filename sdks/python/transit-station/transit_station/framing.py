"""Application codecs compose with the shared native Station frame encoder."""
from pathlib import Path
from typing import TypeVar
from transit_client._native import Library
from transit_client._worker import Worker
from .models import Codec, encoded

T = TypeVar('T')


def encode_cast(value: T, codec: Codec[T], *, native_directory: Path | None = None) -> bytes:
    api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
    worker = Worker(api.contract['minimum_stack_bytes'])
    try:
        def encode() -> bytes:
            caps = api.call('station_growing_capabilities')
            payload = encoded(codec, value, caps['message_bytes'])
            result = api.call('station_frame_encode', 1, 0, payload, len(payload))
            return bytes.fromhex(result)
        return worker.call(encode)
    finally:
        worker.close(lambda: None)
