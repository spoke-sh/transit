# SQL session checks

The [session contract](../../../contracts/SQL_SESSION_V1.md) defines supported
operations; [contribution instructions](AGENTS.md) describe their test boundary.

| Responsibility | Driver |
| --- | --- |
| Independent contract fixtures | [contracts.py](contracts.py) |
| Native and local sessions | [native.py](native.py), [local.py](local.py) |
| Current disclosure rights and resources | [security.py](security.py), [resources.py](resources.py) |
| Disconnects, replacement and cancellation | [faults.py](faults.py), [boundaries.py](boundaries.py) |
| Console peer and measurements | [editor_peer.py](editor_peer.py), [measurements.py](measurements.py) |

Use `just test::sql-sessions` and the affected installed SQL task from the
[test module](../../../tasks/test.just). Measurements describe elapsed work;
they do not replace completion, authorization or recovery assertions.
