set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

# List CI commands; running this default does not qualify any checks.
[default]
_default:
    @just --list ci

# Run every hosted lane sequentially with the pinned language qualification tools.
all:
    nix develop .#bindings --command python3 -B tests/runner/ci.py all

# Run committed HEAD in a clean clone; optionally select one lane or complete CI.
[positional-arguments]
clean *args:
    python3 -B tests/runner/ci_clean.py "$@"

# Ordinary hosted qualification including Chromium (install it first).
complete:
    nix develop .#bindings --command python3 -B tests/runner/ci.py complete

# Preview conservative PR selection between Git revisions.
select base head="HEAD":
    python3 -B tests/runner/ci_select.py --base {{quote(base)}} --head {{quote(head)}}

# Foundation, library and durable protocol proofs.
core:
    python3 -B tests/runner/ci.py core

# Finite models, concrete trace replay and Lean rewrite theorems.
formal:
    python3 -B tests/runner/ci.py formal

# Storage, catalog, query and independent Arrow qualification.
storage-query:
    python3 -B tests/runner/ci.py storage-query

# SQL protocols, relational callers and HTTP/gRPC interfaces.
interfaces:
    python3 -B tests/runner/ci.py interfaces

# Installation, Board, documentation and observability proofs.
installation-ui:
    python3 -B tests/runner/ci.py installation-ui

# Persistent counter launcher, artifact updates and foreground lifecycle.
launchers:
    python3 -B tests/runner/ci.py launchers

# Read hosted run timings and cache cost; requires authenticated GitHub CLI.
cost run:
    python3 -B tests/runner/ci_cost.py --run {{quote(run)}}

# Run all SDK conformance and language suites sequentially.
sdks:
    python3 -B tests/runner/ci.py sdks

# Generated contracts, native boundary and cross-language interoperability.
sdks-conformance:
    python3 -B tests/runner/ci.py sdks-conformance

# Installed Python, Node and Ruby SDK consumers.
sdks-scripting:
    python3 -B tests/runner/ci.py sdks-scripting

# Installed Rust, Go and C/C++ SDK consumers.
sdks-systems:
    python3 -B tests/runner/ci.py sdks-systems

# Installed Java, .NET and Erlang/Elixir SDK consumers.
sdks-managed:
    python3 -B tests/runner/ci.py sdks-managed

# Browser qualification remains explicit for local developers.
browser:
    python3 -B tests/runner/ci.py browser
