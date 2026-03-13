{
  description = "transit development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";

    sift = {
      url = "github:rupurt/sift?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.flake-utils.follows = "flake-utils";
    };
    keel = {
      url = "git+ssh://git@github.com/spoke-sh/keel.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, rust-overlay, flake-utils, keel, sift, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "clippy" "llvm-tools" "rust-analyzer" "rust-src" "rustfmt" ];
        };
        isLinux = pkgs.stdenv.isLinux;
        keelSrc = keel.outPath;
        keelCargoToml = pkgs.lib.importTOML "${keelSrc}/Cargo.toml";
        keelRustPlatform = pkgs.makeRustPlatform {
          cargo = rust;
          rustc = rust;
        };
        keelPkg = keelRustPlatform.buildRustPackage {
          pname = "keel";
          version = keelCargoToml.package.version;
          src = keelSrc;

          cargoLock = {
            lockFile = "${keelSrc}/Cargo.lock";
            outputHashes = {
              "txtplot-0.1.0" = "sha256-PXj4ntPJ1UXda++7gcE+yk2cCLy/CFBMBGxgfBGSH5c=";
            };
          };

          nativeBuildInputs = [
            pkgs.pkg-config
          ];

          nativeCheckInputs = [
            pkgs.git
          ];

          buildInputs = [
            pkgs.zstd
          ];

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Fast CLI for project board management";
            homepage = "https://github.com/rupurt/keel";
            license = licenses.mit;
            maintainers = [ ];
          };
        };
        siftPkg = sift.packages.${system}.sift;
      in {
        packages = {
          keel = keelPkg;
          sift = siftPkg;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            rust
            pkgs.cargo-nextest
            pkgs.cargo-llvm-cov
            keelPkg
            pkgs.just
            pkgs.pkg-config
            siftPkg
          ] ++ pkgs.lib.optionals isLinux [
            pkgs.mold
          ];

          shellHook = ''
            export CARGO_TARGET_DIR="$HOME/.cache/cargo-target/transit"
          '' + pkgs.lib.optionalString isLinux ''
            export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS="''${CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS:+$CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS }-C link-arg=-fuse-ld=mold"
            export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUSTFLAGS="''${CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUSTFLAGS:+$CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUSTFLAGS }-C link-arg=-fuse-ld=mold"
          '';
        };
      });
}
