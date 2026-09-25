set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

# Run both hosted lanes sequentially in the existing development environment.
[default]
_default:
    python3 -B tests/ci.py all

# Foundation, library and durable protocol proofs.
core:
    python3 -B tests/ci.py core

# Frontend, instrumentation, Board and persistent native launcher proofs.
experience:
    python3 -B tests/ci.py experience

# Browser qualification remains explicit for local developers.
browser:
    python3 -B tests/ci.py browser
