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
}:
assert openssl.version == "3.6.4";
let
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
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../build.zig
      ../build.zig.zon
      ../apps
      ../packages
      ../third_party
      ../tests
      (lib.fileset.difference ../examples ../examples/station-sdk)
      ../tasks
      ../contracts
      ../package.json
      ../pnpm-lock.yaml
      ../pnpm-workspace.yaml
    ];
  };
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
    version = "0.1.0";
    inherit src;
    fetcherVersion = 3;
    hash = "sha256-CHemJRusRVhDFUjy5nOe8qodE/5trc3N6ve2ea2AvVc=";
  };
  boardAssets = stdenvNoCC.mkDerivation {
    pname = "transit-board-assets";
    version = "0.1.0";
    inherit src;
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
  version = "0.1.0";
  inherit src;
  nativeBuildInputs = [
    zig
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.libc ];
  configurePhase = ''
    runHook preConfigure
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    zig build transit transit-node transit-query-host transit-board -Dboard-assets=${boardAssets}/assets.zig --system ${zigDependencies} -Dsdk-examples=false -Doptimize=ReleaseSafe -Dcpu=baseline -j$NIX_BUILD_CORES --prefix "$out"
    runHook postBuild
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/transit" --help
    "$out/bin/transit" server --help
    "$out/bin/transit" serve --help
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
