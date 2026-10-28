{
  lib,
  stdenv,
  zig,
  pkg-config,
  openssl,
  autoPatchelfHook,
  transit,
}:
assert openssl.version == "3.6.4";
stdenv.mkDerivation {
  pname = "transit-sql-gateway";
  inherit (transit) version;
  inherit (transit) src;
  nativeBuildInputs = [
    zig
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.libc ];
  configurePhase = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
  '';
  buildPhase = ''
    zig build transit-sql-gateway --system ${transit.zigDependencies} -Dchecks=false -Doptimize=ReleaseSafe -Dcpu=baseline -j$NIX_BUILD_CORES --prefix "$out"
  '';
  dontInstall = true;
  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/transit-sql-gateway" --help
  '';
  meta = {
    description = "Opt-in Transit PostgreSQL and MySQL TLS gateway";
    mainProgram = "transit-sql-gateway";
    platforms = lib.platforms.unix;
  };
}
