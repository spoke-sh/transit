{
  pkgs,
  zig,
  vite-plus,
  ursula,
  minio,
}:
# Board and native launchers need no Kubernetes/provider CLIs or Rust build tools.
# Keep this closure separate so that splitting CI does not copy the full shell.
pkgs.mkShell {
  buildInputs = [
    pkgs.openssl
  ]
  ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.libc ];
  packages = [
    pkgs.just
    pkgs.git
    pkgs.postgresql_18
    pkgs.mysql84
    (pkgs.python3.withPackages (ps: [
      ps.pyyaml
      ps.jsonschema
      ps.pyarrow
      ps.grpcio
      ps.protobuf
    ]))
    pkgs.process-compose
    pkgs.openssl
    pkgs.pkg-config
    zig
    vite-plus
    ursula
    pkgs.nodejs_24
    pkgs.pnpm
  ]
  ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [ minio ];
  shellHook = ''
    source ${./dev-environment.sh}
  '';
}
