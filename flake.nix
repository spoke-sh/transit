{
  description = "Transit runtime development environment";

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
      self,
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
          zig = pkgs.callPackage ./nix/zig.nix {
            upstream = zig-overlay.packages.${system}.master;
          };
          kubectl-transit = pkgs.callPackage ./nix/kubectl-transit.nix { inherit zig; };
          vite-plus = pkgs.callPackage ./nix/vite-plus.nix { };
          transit = pkgs.callPackage ./nix/transit.nix {
            inherit zig vite-plus;
            sourceRevision = self.rev or self.dirtyRev or "unknown";
          };
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
          transit-release = transit.override {
            stdenv = pkgs.pkgsStatic.stdenv;
            openssl = pkgs.pkgsStatic.openssl;
            releaseBuild = true;
          };
          transit-sql-gateway = pkgs.callPackage ./nix/transit-sql-gateway.nix { inherit zig transit; };
          transit-local = pkgs.callPackage ./nix/transit-local.nix { inherit transit; };
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
            transit-sql-gateway
            ursula
            ;
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          inherit (toolchains.${system}) transit-local minio;
        }
        // nixpkgs.lib.optionalAttrs (nixpkgs.lib.hasSuffix "-linux" system) {
          inherit (toolchains.${system}) transit-release;
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
          release = pkgs.mkShellNoCC {
            packages = [
              pkgs.python3
              pkgs.git
              pkgs.gh
              pkgs.kubernetes-helm
              pkgs.skopeo
              pkgs.docker-client
              pkgs.binutils
              pkgs.curl
              pkgs.shellcheck
            ];
          };
          ci-formal = import ./nix/ci-formal.nix { inherit pkgs zig; };
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
          sql-wire =
            let
              tools = import ./nix/sql-wire-tools.nix { inherit pkgs; };
            in
            pkgs.mkShell {
              inputsFrom = [ default ];
              packages = tools.packages;
              PKG_CONFIG_PATH = "${tools.openssl.dev}/lib/pkgconfig";
            };
          ci-bindings = import ./nix/ci-bindings.nix {
            inherit pkgs;
            inherit (toolchains.${system}) sql-tools;
            base = ci-experience;
          };
          ci-experience = import ./nix/ci-experience.nix {
            inherit (toolchains.${system}) minio;
            inherit
              pkgs
              zig
              vite-plus
              ursula
              ;
          };
          default =
            assert pkgs.lib.assertMsg (pkgs.lib.hasPrefix "0.17." zig.version)
              "Transit targets Zig 0.17 master; review the compiler target before updating zig-overlay.";
            pkgs.mkShell {
              # Zig links system libraries directly, outside the C compiler
              # wrapper. Pair its pinned ELF loader with the matching libc and
              # OpenSSL library paths.
              buildInputs = [
                pkgs.openssl
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.libc ];
              packages = [
                pkgs.just
                pkgs.git
                pkgs.duckdb
                pkgs.postgresql_18
                pkgs.mysql84
                (pkgs.python3.withPackages (import ./nix/python-tools.nix))
                pkgs.process-compose
                pkgs.openssl
                pkgs.pkg-config
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
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.strace ]
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
              TRANSIT_GSON_LICENSE = "${tools.gsonLicense}";
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
