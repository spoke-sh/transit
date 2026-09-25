set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

# Run every hosted lane sequentially with the pinned language qualification tools.
[default]
_default:
    nix develop .#bindings --command python3 -B tests/ci.py all

# Ordinary hosted qualification including Chromium (install it first).
complete:
    nix develop .#bindings --command python3 -B tests/ci.py complete

# Preview conservative PR selection between Git revisions.
select base head="HEAD":
    python3 -B tests/ci_select.py --base {{quote(base)}} --head {{quote(head)}}

# Foundation, library and durable protocol proofs.
core:
    python3 -B tests/ci.py core

# Frontend, instrumentation, Board and persistent native launcher proofs.
experience:
    python3 -B tests/ci.py experience

# Shared native boundary and cross-language Station behavior/Arrow proofs.
bindings:
    python3 -B tests/ci.py bindings

# Browser qualification remains explicit for local developers.
browser:
    python3 -B tests/ci.py browser
