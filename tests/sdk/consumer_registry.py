"""Explicit installed-consumer owners for shared language schedules."""
from sdk.consumers.python import python_station_sdk
from sdk.consumers.node import node_station_sdk
from sdk.consumers.rust import rust_station_sdk
from sdk.consumers.ruby import ruby_station_sdk
from sdk.consumers.c import c_station_sdk
from sdk.consumers.java import java_station_sdk
from sdk.consumers.dotnet import dotnet_station_sdk
from sdk.consumers.beam import beam_station_sdk
from sdk.consumers.python import python_client_sdk
from sdk.consumers.node import node_client_sdk
from sdk.consumers.rust import rust_client_sdk
from sdk.consumers.ruby import ruby_client_sdk
from sdk.consumers.c import c_client_sdk
from sdk.consumers.java import java_client_sdk
from sdk.consumers.dotnet import dotnet_client_sdk
from sdk.consumers.beam import beam_client_sdk
from sdk.consumers.go import go_client_sdk
from sdk.direct_sdk_catalog import install_python, install_node

# The programs themselves import installed SDKs only in their isolated process.
# Keep their source and installer ownership explicit for the shared benchmark.
PERFORMANCE_CONSUMERS = {
    "zig": ("tests/sdk/consumers/zig/performance.zig", None),
    "python-sync": ("tests/sdk/consumers/python/python_performance_sdk.py", install_python),
    "python-async": ("tests/sdk/consumers/python/python_performance_sdk.py", install_python),
    "node": ("tests/sdk/consumers/node/node_performance_sdk.mjs", install_node),
}

RAW_RUNNERS = {
    "python": python_client_sdk.run,
    "node": node_client_sdk.run,
    "rust": rust_client_sdk.run,
    "ruby": ruby_client_sdk.run,
    "c": c_client_sdk.run,
    "java": java_client_sdk.run,
    "dotnet": dotnet_client_sdk.run,
    "beam": beam_client_sdk.run,
    "go": go_client_sdk.run,
}

RUNNERS = {
    "python": python_station_sdk.run,
    "node": node_station_sdk.run,
    "rust": rust_station_sdk.run,
    "ruby": ruby_station_sdk.run,
    "c": c_station_sdk.run,
    "java": java_station_sdk.run,
    "dotnet": dotnet_station_sdk.run,
    "beam": beam_station_sdk.run,
}
