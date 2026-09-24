set shell := ["bash", "-euo", "pipefail", "-c"]
set working-directory := ".."

# Native services, persistent data, no container daemon.
mod local 'launchers/local.just'

# The same development scenario in containers.
mod compose 'launchers/compose.just'

# Kubernetes/Substrate recovery and isolation qualification.
mod reference 'launchers/reference.just'

[default]
_default:
    @just --list launchers
