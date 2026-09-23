{
  lib,
  stdenv,
  runCommand,
  just,
  zig,
  vite-plus,
  ursula,
  ursulactl,
  nodejs_24,
  pnpm,
  kubectl,
  k9s,
  k3s,
}:
runCommand "rey-toolchain-check"
  {
    nativeBuildInputs = [
      just
      zig
      vite-plus
      ursula
      ursulactl
      nodejs_24
      pnpm
      kubectl
      k9s
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ k3s ];
  }
  ''
    # The Nix build sandbox has no network: first-use setup must be self-contained.
    export VP_HOME="$TMPDIR/vite-plus"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    mkdir -p "$out" web
    just --version > "$out/just-version"
    zig version > "$out/zig-version"
    node --version > "$out/node-version"
    pnpm --version > "$out/pnpm-version"
    ursula --help > "$out/ursula-help"
    ursulactl --version > "$out/ursulactl-version"
    kubectl version --client > "$out/kubectl-version"
    k9s version --short > "$out/k9s-version"
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      k3s --version > "$out/k3s-version"
    ''}
    vp toolchain --global > "$out/vite-plus-toolchain"
    test "$(vp env which node)" = "$(command -v node)"

    cat > smoke.zig <<'ZIG'
    test "standard library and compiler are usable" {
        try @import("std").testing.expectEqual(@as(u8, 4), @as(u8, 2) + 2);
    }
    ZIG
    zig test smoke.zig

    cat > web/package.json <<'JSON'
    {"name":"rey-toolchain-smoke","private":true,"type":"module"}
    JSON
    cat > web/index.html <<'HTML'
    <!doctype html><html><body><script type="module" src="/main.ts"></script></body></html>
    HTML
    cat > web/main.ts <<'TS'
    const message: string = "Rey toolchain ready";
    document.body.textContent = message;
    TS
    cd web
    vp build --outDir "$out/web"
    test -f "$out/web/index.html"
  ''
