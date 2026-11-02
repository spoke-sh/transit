{ pkgs, zig, vite-plus }:
# Model exploration and concrete Zig/TypeScript replay share the locked tools.
# Use the same locked Lean version as the wider SQL grammar environment.
assert pkgs.lean4.version == "4.29.1";
pkgs.mkShellNoCC {
  packages = [
    pkgs.just
    pkgs.git
    pkgs.python3
    pkgs.tlaplus
    pkgs.lean4
    zig
    vite-plus
    pkgs.nodejs_24
    pkgs.pnpm
  ];
  shellHook = ''
    source ${./dev-environment.sh}
  '';
}
