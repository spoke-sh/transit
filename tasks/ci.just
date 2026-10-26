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

# Growing state, Station and independent Arrow qualification.
growth:
    python3 -B tests/runner/ci.py growth

# Frontend, instrumentation, Board and persistent native launcher proofs.
experience:
    python3 -B tests/runner/ci.py experience

# Persistent counter launcher, artifact updates and foreground lifecycle.
launchers:
    python3 -B tests/runner/ci.py launchers

# Read hosted run timings and cache cost; requires authenticated GitHub CLI.
cost run:
    python3 -B tests/runner/ci_cost.py --run {{quote(run)}}

# Shared native boundary and cross-language Station behavior/Arrow proofs.
bindings:
    python3 -B tests/runner/ci.py bindings

# Independent complete portions of the bindings inventory for hosted execution.
bindings-1:
    python3 -B tests/runner/ci.py bindings-1

bindings-2:
    python3 -B tests/runner/ci.py bindings-2

# Browser qualification remains explicit for local developers.
browser:
    python3 -B tests/runner/ci.py browser
