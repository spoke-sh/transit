"""Exercise Nix source invalidation without compiling runtime or frontend code."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    # Use small independent trees and the real selector with the locked Nix lib.
    # Neither mutations nor temporary fixtures touch the contributor's checkout.
    files = {
        "build.zig": "// native build\n",
        "build.zig.zon": ".{}\n",
        "package.json": '{"name":"root"}\n',
        "pnpm-lock.yaml": "lockfileVersion: '9.0'\n",
        "pnpm-workspace.yaml": "packages: ['packages/ts/*']\n",
        "apps/transit-board-web/package.json": '{"name":"board"}\n',
        "apps/transit-board-web/src/main.ts": "export const value = 1;\n",
        "apps/transit-board-web/AGENTS.md": "Contribution rules\n",
        "packages/ts/client/package.json": '{"name":"client"}\n',
        "packages/ts/client/src/main.ts": "export const value = 1;\n",
        "packages/zig/owner/src/main.zig": "const value = 1;\n",
        "packages/zig/owner/README.md": "Package guide\n",
        "third_party/owner/src/main.zig": "const value = 1;\n",
        "examples/serving/web/package.json": '{"name":"serving"}\n',
        "examples/serving/web/src/main.ts": "export const value = 1;\n",
        "examples/work-items/web/package.json": '{"name":"work-items"}\n',
        "examples/station-sdk/consumer.py": "# excluded SDK consumer\n",
        "sdks/client.py": "# excluded SDK\n",
        "tests/driver.py": "# executable test input\n",
        "tests/README.md": "Test navigation\n",
        "tests/evidence/verification/observation.json": '{}\n',
        "tests/verification/models/History.tla": "---- MODULE History ----\n====\n",
        "tests/runner/suite.json": '{}\n',
        "tests/fuze_benchmarks/results/sample/budgets.json": '{}\n',
        "tasks/embed_web.py": "# asset embedder\n",
        "contracts/transit-board-v1.openapi.json": '{}\n',
    }
    runtime = {"runtime"}
    board = {"runtime", "boardAssets"}
    all_sources = {"runtime", "boardAssets", "frontendDependencies"}
    cases = {
        "test-navigation": ("tests/README.md", set()),
        "instructions": ("apps/transit-board-web/AGENTS.md", set()),
        "package-guide": ("packages/zig/owner/README.md", set()),
        "retained-evidence": ("tests/evidence/verification/observation.json", set()),
        "native-source": ("packages/zig/owner/src/main.zig", runtime),
        "upstream-source": ("third_party/owner/src/main.zig", runtime),
        "test-driver": ("tests/driver.py", runtime),
        "formal-model": ("tests/verification/models/History.tla", runtime),
        "suite-catalog": ("tests/runner/suite.json", runtime),
        "live-budgets": ("tests/fuze_benchmarks/results/sample/budgets.json", runtime),
        "example-source": ("examples/serving/web/src/main.ts", runtime),
        "board-source": ("apps/transit-board-web/src/main.ts", board),
        "browser-library": ("packages/ts/client/src/main.ts", board),
        "embedded-contract": ("contracts/transit-board-v1.openapi.json", board),
        "asset-embedder": ("tasks/embed_web.py", board),
        "root-manifest": ("package.json", all_sources),
        "lockfile": ("pnpm-lock.yaml", all_sources),
        "workspace": ("pnpm-workspace.yaml", all_sources),
        "package-manifest": ("packages/ts/client/package.json", all_sources),
        "new-package": ("packages/ts/new/package.json", all_sources),
        "sdk": ("sdks/client.py", set()),
        "sdk-consumer": ("examples/station-sdk/consumer.py", set()),
    }
    with tempfile.TemporaryDirectory(prefix="transit-nix-inputs-") as directory:
        fixture = Path(directory)
        baseline = fixture / "baseline"
        for name, content in files.items():
            path = baseline / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        for name, (relative, _) in cases.items():
            tree = fixture / name
            shutil.copytree(baseline, tree)
            path = tree / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(files.get(relative, "") + "changed input\n")
        # Select the Git flake, never a raw path flake that could copy ignored
        # build outputs or private contributor notes into the Nix store.
        expression = '''let
              flakeRoot = builtins.getEnv "TRANSIT_NIX_CHECK_ROOT";
              fixtureRoot = builtins.getEnv "TRANSIT_NIX_CHECK_FIXTURE";
              flake = builtins.getFlake ("git+file://" + flakeRoot);
              select = import (flakeRoot + "/nix/build-sources.nix");
              roots = builtins.readDir fixtureRoot;
            in builtins.mapAttrs (name: _: builtins.mapAttrs (_: toString) (select {
              lib = flake.inputs.nixpkgs.lib;
              root = /. + (fixtureRoot + "/" + name);
            })) roots
        '''
        result = subprocess.run(
            ["nix", "eval", "--json", "--impure", "--expr", expression],
            env=os.environ | {"TRANSIT_NIX_CHECK_ROOT": str(ROOT),
                              "TRANSIT_NIX_CHECK_FIXTURE": str(fixture)},
            cwd=ROOT, check=True, stdout=subprocess.PIPE, text=True,
        )
        sources = json.loads(result.stdout)
        assert sources["baseline"].keys() == all_sources
        for name, (_, expected) in cases.items():
            changed = {key for key, path in sources[name].items()
                       if path != sources["baseline"][key]}
            assert changed == expected, f"{name}: expected invalidation {expected}, got {changed}"
    print(f"Nix build inputs: {len(cases)} source invalidation controls passed; no builds executed.")


if __name__ == "__main__":
    main()
