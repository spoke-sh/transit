{
  lib,
  stdenvNoCC,
  zig,
  makeWrapper,
  kubectl,
}:
stdenvNoCC.mkDerivation {
  pname = "kubectl-transit";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ../apps/kubectl-transit;
    fileset = ../apps/kubectl-transit/main.zig;
  };
  nativeBuildInputs = [
    zig
    makeWrapper
  ];
  buildPhase = ''
    runHook preBuild
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    zig build-exe main.zig -O ReleaseSafe -mcpu=baseline -femit-bin=kubectl-transit
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 kubectl-transit "$out/bin/kubectl-transit"
    wrapProgram "$out/bin/kubectl-transit" --prefix PATH : ${lib.makeBinPath [ kubectl ]}
    runHook postInstall
  '';
  meta = {
    description = "Transit Kubernetes inspection plugin";
    mainProgram = "kubectl-transit";
    platforms = lib.platforms.unix;
  };
}
