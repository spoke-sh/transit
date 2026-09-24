"""Values and lifecycle for the checked-in Transit chart in the owned proof."""
import json
import reference as ref


class Chart:
    def __init__(self, state, directory, namespace, images, node_config):
        self.state, self.directory, self.namespace = state, directory, namespace
        self.values = {
            "node": {"nameOverride": "transit", "enabled": False,
                     "image": images["transit-node"], "config": node_config},
            "initialize": {"nameOverride": "initialize"},
            "ursula": {"nameOverride": "ursula", "image": images["ursula"]},
            "maintenance": {"nameOverride": "maintenance"},
            "board": {"nameOverride": "board", "image": images["transit-board"]},
            "workerPool": {"nameOverride": "counter"},
        }

    def deploy(self, **changes):
        for component, values in changes.items():
            self.values.setdefault(component, {}).update(values)
        # Public configuration only. Secrets are created separately and referenced
        # by name so Helm release history never receives credential material.
        values_file = self.directory / "transit-values.json"
        values_file.write_text(json.dumps(self.values, indent=2))
        ref.run(["helm", "--kubeconfig", ref.CACHE / "kubeconfig", "--kube-context", "kind-" + self.state["cluster"],
                 "upgrade", "--install", "transit", ref.ROOT / "charts/transit", "--namespace", self.namespace,
                 "--values", values_file, "--wait", "--wait-for-jobs", "--timeout", "180s", "--history-max", "5"])
