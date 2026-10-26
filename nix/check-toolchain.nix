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
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      test "$(patchelf --print-interpreter linkage)" = "${stdenv.cc.bintools.dynamicLinker}"
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
    cat > linkage.c <<'C'
    #include <openssl/crypto.h>
    #include <pthread.h>
    static void *probe(void *result) {
        *(int *)result = OpenSSL_version_num() == 0;
        return 0;
    }
    int main(void) {
        pthread_t thread;
        int result = 1;
        if (pthread_create(&thread, 0, probe, &result)) return 2;
        if (pthread_join(thread, 0)) return 3;
        return result;
    }
    C
    zig cc linkage.c -lcrypto -lpthread -o c-linkage
    ./c-linkage
    zig c++ -x c++ linkage.c -lcrypto -lpthread -o cpp-linkage
    ./cpp-linkage
    # Compile-only callers must not receive unused linker arguments.
    zig cc -Werror -c linkage.c -o c-linkage.o
    zig c++ -Werror -x c++ -c linkage.c -o cpp-linkage.o
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      test "$(patchelf --print-interpreter zig-out/bin/linkage)" = "${stdenv.cc.bintools.dynamicLinker}"
      test "$(patchelf --print-interpreter c-linkage)" = "${stdenv.cc.bintools.dynamicLinker}"
      test "$(patchelf --print-interpreter cpp-linkage)" = "${stdenv.cc.bintools.dynamicLinker}"
      # Explicit target settings belong to the caller. Inspect this deliberately
      # non-runnable loader path without attempting to execute the result.
      zig build -Ddynamic-linker=/transit-toolchain-explicit-loader
      test "$(patchelf --print-interpreter zig-out/bin/linkage)" = /transit-toolchain-explicit-loader
      zig build-exe linkage.zig -lc -lcrypto --dynamic-linker /transit-toolchain-explicit-loader -femit-bin=explicit-linkage
      test "$(patchelf --print-interpreter explicit-linkage)" = /transit-toolchain-explicit-loader
      zig cc linkage.c -lcrypto -lpthread -Wl,--dynamic-linker,/transit-toolchain-explicit-loader -o explicit-c-linkage
      test "$(patchelf --print-interpreter explicit-c-linkage)" = /transit-toolchain-explicit-loader
      zig c++ -x c++ linkage.c -lcrypto -lpthread -Xlinker --dynamic-linker -Xlinker /transit-toolchain-explicit-loader -o explicit-cpp-linkage
      test "$(patchelf --print-interpreter explicit-cpp-linkage)" = /transit-toolchain-explicit-loader
      # An explicit musl target must not acquire the native GNU headers/loader.
      cat > explicit-target.c <<'C'
      #include <features.h>
      #ifdef __GLIBC__
      #error Explicit musl target received glibc headers
      #endif
      int main(void) { return 0; }
      C
      zig cc --target=${stdenv.hostPlatform.parsed.cpu.name}-linux-musl -static explicit-target.c -o explicit-target
      ./explicit-target
      if patchelf --print-interpreter explicit-target > /dev/null 2>&1; then
        echo "Explicit static target unexpectedly has an ELF interpreter" >&2
        exit 1
      fi
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
