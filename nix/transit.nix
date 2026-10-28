{
  lib,
  stdenv,
  runCommand,
  fetchurl,
  autoPatchelfHook,
  zig,
  stdenvNoCC,
  fetchPnpmDeps,
  pnpm,
  python3,
  zstd,
  vite-plus,
  openssl,
  pkg-config,
  sourceRevision ? "unknown",
  releaseBuild ? false,
}:
assert openssl.version == "3.6.4";
let
  version = lib.trim (builtins.readFile ../VERSION);
  # Seed Zig's package directory from fixed-output downloads. The build itself
  # runs offline and verifies the same package identities as build.zig.zon.
  dependencies = [
    {
      repo = "ursula-zig";
      rev = "2d507829429d4199f411df02df9cc937bf624144";
      hash = "sha256-AyMigYnv2/NDjh5txzKUfzbkE8g2f9w8vT/IsdsaEKY=";
      zigHash = "ursula_zig-0.0.0-rb5hFJsaAgDo2SoUt3p32weNLReXIqRxQjSonL1Ytq5q";
    }
    {
      repo = "zarrow";
      rev = "4276ac30d63d1af159490b7dc70e15d749b8d01b";
      hash = "sha256-28o+5LlPtFS0szT8E90fIa5h4HFNxt429NGWo+s1Dhc=";
      zigHash = "zarrow-0.0.2-I8BLE0uOTgDQAtAvsgOOCmJgZu10cSYsaqPgFSjXyGe7";
    }
    {
      repo = "zarrow-compute";
      rev = "def4d0654b4d6cdc2f4a7e6ad4a5930301f3391a";
      hash = "sha256-PV85OJd8ZLu/yWmeeW5sFgPbMdoN4lUCxdhIGQtgHM8=";
      zigHash = "zarrow_compute-0.0.1-8ayHKy0VBwDAfERQv8gzeXZhfy9yxC91uqWfQqMqrWZa";
    }
  ];
  zigDependencies = runCommand "transit-zig-dependencies" { nativeBuildInputs = [ zig ]; } ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    ${lib.concatMapStringsSep "\n" (
      dep:
      let
        archive = fetchurl {
          name = "${dep.repo}-${dep.rev}.tar.gz";
          url = "https://codeload.github.com/rupurt/${dep.repo}/tar.gz/${dep.rev}";
          inherit (dep) hash;
        };
      in
      ''
        test "$(zig fetch ${archive})" = ${lib.escapeShellArg dep.zigHash}
        mkdir -p "$out/${dep.zigHash}"
        tar -xf ${archive} --strip-components=1 -C "$out/${dep.zigHash}"
      ''
    ) dependencies}
  '';
  sources = import ./build-sources.nix {
    inherit lib;
    root = ../.;
  };
  src = sources.runtime;
  # Match package.json exactly so Vite+ never bootstraps a package manager in
  # the network-isolated asset build. This does not change the developer shell.
  frontendPnpm = pnpm.override {
    version = "10.32.1";
    hash = "sha256-m5Q7lLyPVe+5k6rY5EtTjmsJHmCp5KlE3N6GmFXyM+M=";
  };
  frontendVp = vite-plus.override { pnpm = frontendPnpm; };
  frontendDeps = fetchPnpmDeps {
    pnpm = frontendPnpm;
    pname = "transit-board";
    inherit version;
    src = sources.frontendDependencies;
    fetcherVersion = 3;
    hash = "sha256-4BLKRRPbJSCXwxrBCHlJ380XpiPmT7gg9MerGRAt3g4=";
  };
  boardAssets = stdenvNoCC.mkDerivation {
    pname = "transit-board-assets";
    inherit version;
    src = sources.boardAssets;
    nativeBuildInputs = [
      python3
      zstd
      frontendVp
    ];
    configurePhase = ''
      export VP_HOME="$TMPDIR/vite-plus"
      mkdir -p "$TMPDIR/pnpm-store"
      tar --zstd -xf ${frontendDeps}/pnpm-store.tar.zst -C "$TMPDIR/pnpm-store"
      chmod -R u+w "$TMPDIR/pnpm-store"
      vp install --offline --frozen-lockfile --ignore-scripts -- --store-dir "$TMPDIR/pnpm-store"
    '';
    buildPhase = ''
      python3 -B tasks/embed_web.py "$out/assets.zig" apps/transit-board-web contracts/transit-board-v1.openapi.json
    '';
    dontInstall = true;
  };
in
stdenv.mkDerivation {
  pname = "transit";
  inherit version;
  inherit src;
  nativeBuildInputs = [
    zig
    pkg-config
  ]
  ++ lib.optionals releaseBuild [ python3 ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.libc ];
  configurePhase = ''
    runHook preConfigure
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    zig build transit transit-node transit-query-host transit-board ${lib.optionalString releaseBuild "transit-admin transit-delivery transit-station-controller -Dtarget=x86_64-linux-musl"} -Dsource-revision=${lib.escapeShellArg sourceRevision} -Dboard-assets=${boardAssets}/assets.zig --system ${zigDependencies} -Dchecks=false -Doptimize=ReleaseSafe -Dcpu=baseline -j$NIX_BUILD_CORES --prefix "$out"
    ${lib.optionalString releaseBuild ''
      python3 -B tasks/release_notices.py "$out/share/transit/notices" ${zigDependencies} ${openssl.src} ${stdenv.cc.libc.src}
    ''}
    runHook postBuild
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/transit" --help
    test "$("$out/bin/transit" --version)" = "Transit ${version} (git ${sourceRevision}; CLI contract 1)"
    "$out/bin/transit" server --help
    "$out/bin/transit" console --help
    runHook postInstallCheck
  '';
  dontInstall = true;
  passthru = { inherit zigDependencies boardAssets frontendDeps; };
  meta = {
    description = "Transit CLI and matching native runtime artifacts";
    mainProgram = "transit";
    platforms = lib.platforms.unix;
  };
}
