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
          vite-plus = pkgs.callPackage ./nix/vite-plus.nix { };
          transit = pkgs.callPackage ./nix/transit.nix { inherit zig vite-plus; };
          minio = pkgs.callPackage ./nix/minio.nix { };
          ursula = import ./nix/ursula.nix { upstream = ursula-overlay.packages.${system}.ursula; };
          reference = pkgs.callPackage ./nix/reference-tools.nix {
            pins = builtins.fromJSON (builtins.readFile ./deploy/reference/versions.json);
          };
        in
        {
          inherit pkgs;
          sql-tools = pkgs.callPackage ./nix/sql-tools.nix { };
          inherit (reference) kind kubectl-ate;
          inherit (ursula-overlay.packages.${system}) ursulactl;
          inherit ursula;
          inherit zig kubectl-transit;
          inherit transit minio;
          transit-local = pkgs.callPackage ./nix/transit-local.nix {
            inherit transit minio ursula;
          };
          inherit vite-plus;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        {
          inherit (toolchains.${system})
            kind
            kubectl-ate
            kubectl-transit
            sql-tools
            transit
            ursula
            ;
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          inherit (toolchains.${system}) transit-local minio;
        }
      );

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
          docs = pkgs.mkShellNoCC {
            packages = [
              pkgs.just
              pkgs.git
              vite-plus
              pkgs.nodejs_24
              pkgs.pnpm
            ];
            shellHook = ''
              source ${./nix/dev-environment.sh}
            '';
          };
          flight = pkgs.mkShell {
            inputsFrom = [ serving ];
            packages = [ (pkgs.callPackage ./nix/flight-tools.nix { }) ];
          };
          benchmarks = pkgs.mkShell {
            inputsFrom = [ default ];
            TRANSIT_FUZE_BENCH_PYTHON = "${pkgs.callPackage ./nix/fuze-benchmark-tools.nix { }}/bin/python3";
          };
          serving = pkgs.mkShell {
            inputsFrom = [ default ];
            packages = [ pkgs.nginx ];
          };
          ci-bindings = import ./nix/ci-bindings.nix {
            inherit pkgs;
            inherit (toolchains.${system}) sql-tools minio;
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
                pkgs.duckdb
                (pkgs.python3.withPackages (ps: [
                  ps.pyyaml
                  ps.jsonschema
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
                pkgs.openssl
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
              ]
              ++ pkgs.lib.optionals (system == "x86_64-linux") [ toolchains.${system}.minio ];

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
