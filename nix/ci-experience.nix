{
  pkgs,
  zig,
  vite-plus,
  ursula,
}:
# Board and native launchers need no Kubernetes/provider CLIs or Rust build tools.
# Keep this closure separate so that splitting CI does not copy the full shell.
pkgs.mkShellNoCC {
  packages = [
    pkgs.just
    pkgs.git
    (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
    pkgs.process-compose
    zig
    vite-plus
    ursula
    pkgs.nodejs_24
    pkgs.pnpm
  ];
  shellHook = ''
    source ${./dev-environment.sh}
  '';
}
