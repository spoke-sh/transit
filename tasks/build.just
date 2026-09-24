set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

[default]
_default:
    @just --unsorted --list build

# Build for debugging, with runtime safety checks and no optimization.
[positional-arguments]
debug *args:
    zig build -Doptimize=debug "$@"

# Build optimized executables with runtime safety checks enabled.
[positional-arguments]
release-safe *args:
    zig build -Doptimize=safe "$@"

# Build for speed, with runtime safety checks disabled by default.
[positional-arguments]
release-fast *args:
    zig build -Doptimize=fast "$@"

# Build for small executables, with runtime safety checks disabled by default.
[positional-arguments]
release-small *args:
    zig build -Doptimize=small "$@"
