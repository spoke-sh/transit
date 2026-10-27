"""Explicit installed-consumer owners for shared language schedules."""
from sdk.consumers.python import python_station_sdk
from sdk.consumers.node import node_station_sdk
from sdk.consumers.rust import rust_station_sdk
from sdk.consumers.ruby import ruby_station_sdk
from sdk.consumers.c import c_station_sdk
from sdk.consumers.java import java_station_sdk
from sdk.consumers.dotnet import dotnet_station_sdk
from sdk.consumers.beam import beam_station_sdk

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
