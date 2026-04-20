{ pkgs
, version ? (pkgs.lib.importTOML ../Cargo.toml).workspace.package.version
}:

pkgs.rustPlatform.buildRustPackage {
  pname = "transit";
  inherit version;
  src = ../.;
  cargoLock = {
    lockFile = ../Cargo.lock;
  };
  doCheck = false;
  cargoBuildFlags = [ "-p" "transit-cli" ];
  cargoCheckFlags = [ "-p" "transit-cli" ];
  sourceRoot = ".";
}
