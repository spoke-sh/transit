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
          zig = zig-overlay.packages.${system}.master;
          kubectl-transit = pkgs.callPackage ./nix/kubectl-transit.nix { inherit zig; };
          reference = pkgs.callPackage ./nix/reference-tools.nix {
            pins = builtins.fromJSON (builtins.readFile ./deploy/reference/versions.json);
          };
        in
        {
          inherit pkgs;
          sql-tools = pkgs.callPackage ./nix/sql-tools.nix { };
          inherit (reference) kind kubectl-ate;
          inherit (ursula-overlay.packages.${system}) ursula ursulactl;
          inherit zig kubectl-transit;
          vite-plus = pkgs.callPackage ./nix/vite-plus.nix { };
        }
      );
    in
    {
      packages = forAllSystems (system: {
        inherit (toolchains.${system})
          kind
          kubectl-ate
          kubectl-transit
          sql-tools
          ;
      });

      devShells = forAllSystems (
        system:
        let
          inherit (toolchains.${system})
            pkgs
            zig
            vite-plus
            ursula
            ursulactl
            kind
            kubectl-ate
            kubectl-transit
            ;
        in
        rec {
          ci-bindings = import ./nix/ci-bindings.nix {
            inherit pkgs;
            inherit (toolchains.${system}) sql-tools;
            base = ci-experience;
          };
          ci-experience = import ./nix/ci-experience.nix {
            inherit
              pkgs
              zig
              vite-plus
              ursula
              ;
          };
          default =
            assert pkgs.lib.assertMsg (pkgs.lib.hasPrefix "0.17." zig.version)
              "Rey targets Zig 0.17 master; review the compiler target before updating zig-overlay.";
            pkgs.mkShell {
              packages = [
                pkgs.just
                pkgs.git
                (pkgs.python3.withPackages (ps: [
                  ps.pyyaml
                  ps.pyarrow
                  ps.grpcio
                  ps.protobuf
                  ps.h2
                  ps.build
                  ps.setuptools
                  ps.wheel
                  ps.pip
                  ps.mypy
                ]))
                pkgs.process-compose
                pkgs.protobuf
                zig
                vite-plus
                ursula
                ursulactl
                pkgs.nodejs_24
                pkgs.pnpm
                pkgs.nixfmt
                pkgs.actionlint
                pkgs.kubectl
                pkgs.kubernetes-helm
                pkgs.k9s
                kind
                kubectl-ate
                kubectl-transit
              ];

              # Keep tool state and the default Kubernetes context checkout-local.
              shellHook = ''
                source ${./nix/dev-environment.sh}
              '';
            };
          bindings =
            let
              tools = import ./nix/bindings-tools.nix { inherit pkgs; };
            in
            pkgs.mkShell {
              inputsFrom = [ default ];
              packages = tools.packages;
              TRANSIT_SQL_TOOLS = "${toolchains.${system}.sql-tools}";
              TRANSIT_GSON_JAR = "${tools.gson}";
              DOTNET_CLI_TELEMETRY_OPTOUT = "1";
              DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1";
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
            kind
            kubectl-ate
            kubectl-transit
            ;
        in
        {
          toolchain = pkgs.callPackage ./nix/check-toolchain.nix {
            inherit
              zig
              vite-plus
              ursula
              ursulactl
              kind
              kubectl-ate
              kubectl-transit
              ;
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
