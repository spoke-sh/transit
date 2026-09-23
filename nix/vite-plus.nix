{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nodejs_24,
  pnpm,
}:
let
  version = "0.3.3";
  # Upstream release assets and vp-checksums.txt:
  # https://github.com/voidzero-dev/vite-plus/releases/tag/v0.3.3
  releases = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-Cs804xgtIPJFtY+wpMYRMpsED2TZ0rdrkbvZB7yfxPg=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-s8r7lUViOFmRDOBqkF2i09V3/kwVVYeVuN3Qnh++ntE=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-dQlQAZcqaXTqGUPSXijcR716f3f4OHBV5w2GpJmneMI=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-hWcToxjxzDszyd+s58ou8Gbxjt6BUPN7f1SQYNRwmDQ=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
buildNpmPackage {
  pname = "vite-plus";
  inherit version;

  src = ./vite-plus;
  nodejs = nodejs_24;
  npmDepsHash = "sha256-b/qJu6j4I1NCslHNKA7rhJ/Vo/vwhTno4ZTW5WLs+Ao=";
  npmFlags = [ "--ignore-scripts" ];
  npmInstallFlags = lib.optionals stdenv.hostPlatform.isLinux [ "--libc=glibc" ];
  dontNpmBuild = true;

  cli = fetchurl {
    url = "https://github.com/voidzero-dev/vite-plus/releases/download/v${version}/vp-${release.target}.tar.gz";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$cli" -C "$out/bin"
    cp -R node_modules "$out/"
    chmod +x "$out/bin/vp"
    wrapProgram "$out/bin/vp" \
      --prefix PATH : "${
        lib.makeBinPath [
          nodejs_24
          pnpm
        ]
      }" \
      --set VP_SELF_SETUP_NO_MODIFY_PATH 1 \
      --set VP_NODE_MANAGER no \
      --set VP_PM_MANAGER no ${lib.optionalString stdenv.hostPlatform.isLinux ''
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
      ''}
    runHook postInstall
  '';

  meta = {
    description = "Vite+ global CLI for frontend development";
    homepage = "https://viteplus.dev";
    license = lib.licenses.mit;
    mainProgram = "vp";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
