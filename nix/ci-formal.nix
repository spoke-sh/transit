{ pkgs, zig }:
# Model exploration and concrete Zig replay need no frontend, provider or SDK.
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
  ];
  shellHook = ''
    source ${./dev-environment.sh}
  '';
}
