{
  description = "transit development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";

    keel = {
      url = "git+ssh://git@github.com/spoke-sh/keel.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, rust-overlay, flake-utils, keel, ... }:
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
        keelPkg = keel.packages.${system}.keel;
      in {
        packages = {
          keel = keelPkg;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            rust
            pkgs.cargo-nextest
            pkgs.cargo-llvm-cov
            keelPkg
            pkgs.just
            pkgs.pkg-config
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
