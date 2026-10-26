{
  runCommand,
  lib,
  stdenv,
  patchelf,
  pkg-config,
  just,
  python3,
  process-compose,
  openssl,
  postgresql_18,
  mysql84,
  zig,
  vite-plus,
  ursula,
  ursulactl,
  nodejs_24,
  pnpm,
  kubectl,
  kubernetes-helm,
  k9s,
  kind,
  kubectl-ate,
  kubectl-transit,
}:
runCommand "transit-toolchain-check"
  {
    buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.libc ];
    nativeBuildInputs = [
      just
      stdenv.cc
      pkg-config
      (python3.withPackages (ps: [ ps.pyyaml ]))
      process-compose
      openssl
      postgresql_18
      mysql84
      zig
      vite-plus
      ursula
      ursulactl
      nodejs_24
      pnpm
      kubectl
      kubernetes-helm
      k9s
      kind
      kubectl-ate
      kubectl-transit
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ patchelf ];
  }
  ''
    # The Nix build sandbox has no network: first-use setup must be self-contained.
    export VP_HOME="$TMPDIR/vite-plus"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    mkdir -p "$out" web
    just --version > "$out/just-version"
    python3 --version > "$out/python-version"
    python3 -c 'import yaml; assert yaml.safe_load("enabled: true")["enabled"]'
    process-compose version > "$out/process-compose-version"
    openssl version > "$out/openssl-version"
    psql --version > "$out/psql-version"
    mysql --version > "$out/mysql-version"
    zig version > "$out/zig-version"
    node --version > "$out/node-version"
    pnpm --version > "$out/pnpm-version"
    ursula --help > "$out/ursula-help"
    ursulactl --version > "$out/ursulactl-version"
    kubectl version --client > "$out/kubectl-version"
    helm version --short > "$out/helm-version"
    k9s version --short > "$out/k9s-version"
    kind version > "$out/kind-version"
    kubectl ate --version > "$out/kubectl-ate-version"
    kubectl ate --help > "$out/kubectl-ate-help"
    kubectl transit --version > "$out/kubectl-transit-version"
    kubectl transit --help > "$out/kubectl-transit-help"
    kubectl plugin list > "$out/kubectl-plugins"
    vp toolchain --global > "$out/vite-plus-toolchain"
    test "$(vp env which node)" = "$(command -v node)"

    cat > smoke.zig <<'ZIG'
    test "standard library and compiler are usable" {
        try @import("std").testing.expectEqual(@as(u8, 4), @as(u8, 2) + 2);
    }
    ZIG
    zig test smoke.zig

    # Exercise both direct compiler and build-runner target selection. Running
    # on a new host alone would miss the older Ubuntu loader mismatch.
    cat > linkage.zig <<'ZIG'
    extern "c" fn OpenSSL_version_num() c_ulong;
    pub fn main() void {
        if (OpenSSL_version_num() == 0) @panic("OpenSSL did not load");
    }
    ZIG
    zig build-exe linkage.zig -lc -lcrypto -femit-bin=linkage
    ./linkage
    cat > linkage.c <<'C'
    #include <openssl/crypto.h>
    int main(void) { return OpenSSL_version_num() == 0; }
    C
    cp linkage.c linkage.cpp
    zig cc linkage.c $(pkg-config --cflags --libs libcrypto) -o linkage-c
    zig c++ linkage.cpp $(pkg-config --cflags --libs libcrypto) -o linkage-cpp
    ./linkage-c
    ./linkage-cpp
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      test "$(patchelf --print-interpreter linkage)" = "${stdenv.cc.bintools.dynamicLinker}"
      test "$(patchelf --print-interpreter linkage-c)" = "${stdenv.cc.bintools.dynamicLinker}"
      test "$(patchelf --print-interpreter linkage-cpp)" = "${stdenv.cc.bintools.dynamicLinker}"
      zig cc linkage.c $(pkg-config --cflags --libs libcrypto) -Wl,--dynamic-linker=/transit-toolchain-c-loader -o explicit-c
      test "$(patchelf --print-interpreter explicit-c)" = /transit-toolchain-c-loader
      zig c++ -target native-native-gnu.${lib.versions.majorMinor stdenv.cc.libc.version} linkage.cpp $(pkg-config --cflags --libs libcrypto) -Xlinker --dynamic-linker -Xlinker /transit-toolchain-cpp-loader -o explicit-cpp
      test "$(patchelf --print-interpreter explicit-cpp)" = /transit-toolchain-cpp-loader
    ''}
    cat > build.zig <<'ZIG'
    const std = @import("std");
    pub fn build(b: *std.Build) void {
        const mod = b.createModule(.{
            .root_source_file = b.path("linkage.zig"),
            .target = b.standardTargetOptions(.{}),
            .link_libc = true,
        });
        mod.linkSystemLibrary("crypto", .{});
        b.installArtifact(b.addExecutable(.{ .name = "linkage", .root_module = mod }));
    }
    ZIG
    zig build
    ./zig-out/bin/linkage
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      test "$(patchelf --print-interpreter zig-out/bin/linkage)" = "${stdenv.cc.bintools.dynamicLinker}"
      # Explicit target settings belong to the caller. Inspect this deliberately
      # non-runnable loader path without attempting to execute the result.
      zig build -Ddynamic-linker=/transit-toolchain-explicit-loader
      test "$(patchelf --print-interpreter zig-out/bin/linkage)" = /transit-toolchain-explicit-loader
      zig build-exe linkage.zig -lc -lcrypto --dynamic-linker /transit-toolchain-explicit-loader -femit-bin=explicit-linkage
      test "$(patchelf --print-interpreter explicit-linkage)" = /transit-toolchain-explicit-loader
    ''}

    # Dependencies receive serialized target options. Exercise both accepted
    # target types so the loader cannot disappear between package boundaries.
    mkdir -p nested/child
    cp linkage.zig nested/child/main.zig
    cat > nested/build.zig.zon <<'ZON'
    .{ .name = .transit_loader_probe, .version = "0.0.0", .fingerprint = 0x79856726ec4a8d35, .dependencies = .{ .child = .{ .path = "child" } }, .paths = .{"build.zig", "build.zig.zon", "child"} }
    ZON
    cat > nested/child/build.zig.zon <<'ZON'
    .{ .name = .transit_loader_child, .version = "0.0.0", .fingerprint = 0x8c685c25f6fa32dd, .paths = .{"build.zig", "build.zig.zon", "main.zig"} }
    ZON
    cat > nested/build.zig <<'ZIG'
    const std = @import("std");
    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        b.installArtifact(b.dependency("child", .{ .target = target }).artifact("child"));
        b.installArtifact(b.dependency("child", .{ .target = target.query }).artifact("child-query"));
    }
    ZIG
    cat > nested/child/build.zig <<'ZIG'
    const std = @import("std");
    pub fn build(b: *std.Build) void {
        const mod = b.createModule(.{ .root_source_file = b.path("main.zig"), .target = b.standardTargetOptions(.{}), .link_libc = true });
        mod.linkSystemLibrary("crypto", .{});
        b.installArtifact(b.addExecutable(.{ .name = "child", .root_module = mod }));
        b.installArtifact(b.addExecutable(.{ .name = "child-query", .root_module = mod }));
    }
    ZIG
    zig build --build-file nested/build.zig
    ./nested/zig-out/bin/child
    ./nested/zig-out/bin/child-query
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      test "$(patchelf --print-interpreter nested/zig-out/bin/child)" = "${stdenv.cc.bintools.dynamicLinker}"
      test "$(patchelf --print-interpreter nested/zig-out/bin/child-query)" = "${stdenv.cc.bintools.dynamicLinker}"
      zig build --build-file nested/build.zig -Ddynamic-linker=/transit-toolchain-dependency-loader
      test "$(patchelf --print-interpreter nested/zig-out/bin/child)" = /transit-toolchain-dependency-loader
      test "$(patchelf --print-interpreter nested/zig-out/bin/child-query)" = /transit-toolchain-dependency-loader
    ''}

    cat > web/package.json <<'JSON'
    {"name":"transit-toolchain-smoke","private":true,"type":"module"}
    JSON
    cat > web/index.html <<'HTML'
    <!doctype html><html><body><script type="module" src="/main.ts"></script></body></html>
    HTML
    cat > web/main.ts <<'TS'
    const message: string = "Transit toolchain ready";
    document.body.textContent = message;
    TS
    cd web
    vp build --outDir "$out/web"
    test -f "$out/web/index.html"
  ''
