{
  description = "Rey trading system development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ursula-overlay = {
      url = "github:rupurt/ursula-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      zig-overlay,
      ursula-overlay,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
      toolchains = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit pkgs;
          inherit (ursula-overlay.packages.${system}) ursula ursulactl;
          zig = zig-overlay.packages.${system}.master;
          vite-plus = pkgs.callPackage ./nix/vite-plus.nix { };
        }
      );
    in
    {
      devShells = forAllSystems (
        system:
        let
          inherit (toolchains.${system})
            pkgs
            zig
            vite-plus
            ursula
            ursulactl
            ;
        in
        {
          default =
            assert pkgs.lib.assertMsg (pkgs.lib.hasPrefix "0.17." zig.version)
              "Rey targets Zig 0.17 master; review the compiler target before updating zig-overlay.";
            pkgs.mkShell {
              packages = [
                pkgs.just
                (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
                pkgs.process-compose
                zig
                vite-plus
                ursula
                ursulactl
                pkgs.nodejs_24
                pkgs.pnpm
                pkgs.nixfmt
                pkgs.kubectl
                pkgs.kubernetes-helm
                pkgs.k9s
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.k3s ];

              # Isolate Vite+'s first-run setup from the user's global installation.
              shellHook = ''
                export VP_HOME="$PWD/.cache/vite-plus"
              '';
            };
        }
      );

      checks = forAllSystems (
        system:
        let
          inherit (toolchains.${system})
            pkgs
            zig
            vite-plus
            ursula
            ursulactl
            ;
        in
        {
          toolchain = pkgs.callPackage ./nix/check-toolchain.nix {
            inherit
              zig
              vite-plus
              ursula
              ursulactl
              ;
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
