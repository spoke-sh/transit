# Sourced by the Nix shell and again after direnv loads optional .env settings.
# A missing reference config must not send commands to the user's global cluster.
transit_checkout=$(git rev-parse --show-toplevel 2>/dev/null) || transit_checkout=$PWD
export VP_HOME="$transit_checkout/.cache/vite-plus"
export KUBECONFIG="${TRANSIT_KUBECONFIG:-$transit_checkout/.cache/reference/kubeconfig}"
unset transit_checkout
