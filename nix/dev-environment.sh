# Sourced by the Nix shell and again after direnv loads optional .env settings.
# A missing reference config must not send commands to the user's global cluster.
rey_checkout=$(git rev-parse --show-toplevel 2>/dev/null) || rey_checkout=$PWD
export VP_HOME="$rey_checkout/.cache/vite-plus"
export KUBECONFIG="${REY_KUBECONFIG:-$rey_checkout/.cache/reference/kubeconfig}"
unset rey_checkout
