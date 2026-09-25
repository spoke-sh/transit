set shell := ["bash", "-euo", "pipefail", "-c"]

set working-directory := "../.."

[default]
_default:
    @just --list launchers reference

# Start a complete persistent Transit installation on the owned Kind/Substrate cluster.
[positional-arguments]
up *args:
    python3 -B launchers/main.py reference up "$@"

# Build candidates without changing deployed images.
[positional-arguments]
build *args:
    python3 -B launchers/main.py reference build "$@"

# Apply compatible service/workload changes; --no-build selects saved candidates.
[positional-arguments]
update *args:
    python3 -B launchers/main.py reference update "$@"

# Stop application services and workers; preserve cluster, PVC, realm and PID.
down:
    python3 -B launchers/main.py reference down

status:
    python3 -B launchers/main.py reference status

endpoints:
    python3 -B launchers/main.py reference endpoints

inspect:
    python3 -B launchers/main.py reference inspect

logs service="node":
    python3 -B launchers/main.py reference logs {{quote(service)}}

restart service:
    python3 -B launchers/main.py reference restart {{quote(service)}}

send value request_id="":
    python3 -B launchers/main.py reference send {{quote(value)}} --request-id {{quote(request_id)}}

# Attach the host access/log manager; detaching leaves Kubernetes services running.
attach:
    python3 -B launchers/main.py reference attach

# Delete this stopped application's Kubernetes namespace and local credentials.
reset:
    python3 -B launchers/main.py reference reset

# Create only provider infrastructure (used by isolated recovery proofs).
infra-up:
    python3 -B tests/reference.py up

# Destroy the entire owned cluster and registry, including every installation.
infra-down:
    python3 -B tests/reference.py down

# Build images needed by the separate destructive recovery/isolation proof.
images:
    python3 -B tests/reference.py images

# Kill test workers/controllers in a separate proof installation.
test:
    python3 -B tests/reference_workload.py

# Qualify persistent startup, targeted updates and same-PID image upgrades separately.
test-launcher:
    python3 -B tests/reference_launcher.py

# Kill a real Station worker in a separately named three-Actor installation.
test-station:
    python3 -B tests/station_launchers.py reference

# Inspect a temporary namespace without restarting existing workloads.
test-plugin:
    zig build kubectl-transit
    python3 -B tests/kubectl_transit_cluster.py zig-out/bin/kubectl-transit
