{
  lib,
  stdenv,
  symlinkJoin,
  writeShellScript,
  upstream,
}:
# The prebuilt compiler detects the host distribution's ELF interpreter. Native
# programs linked to Nix libraries must instead use the matching Nix loader.
# Keep the locked compiler; explicit targets retain upstream behavior.
if !stdenv.hostPlatform.isLinux then
  upstream
else
  let
    compiler =
      assert lib.assertMsg (
        upstream.version == "0.17.0-dev.2267+48abf1a34"
      ) "Review the Zig build-runner loader lifetime patch when changing the compiler pin.";
      upstream.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./zig-dynamic-linker.patch ];
      });
    wrapper = writeShellScript "transit-zig" ''
      if [ "$#" -eq 0 ]; then
        exec ${compiler}/bin/zig
      fi
      command=$1
      shift
      case "$command" in
        build)
          for arg in "$@"; do
            case "$arg" in
              --) break ;;
              -Dtarget=*|-Ddynamic-linker=*) exec ${compiler}/bin/zig "$command" "$@" ;;
            esac
          done
          exec ${compiler}/bin/zig build -Ddynamic-linker=${stdenv.cc.bintools.dynamicLinker} "$@"
          ;;
        build-exe|build-lib|run|test)
          for arg in "$@"; do
            case "$arg" in
              --) break ;;
              -target|--dynamic-linker|--dynamic-linker=*|--no-dynamic-linker) exec ${compiler}/bin/zig "$command" "$@" ;;
            esac
          done
          exec ${compiler}/bin/zig "$command" --dynamic-linker ${stdenv.cc.bintools.dynamicLinker} "$@"
          ;;
        cc|c++)
          link=true
          default_loader=true
          for arg in "$@"; do
            case "$arg" in
              --) break ;;
              -target|--target|-target=*|--target=*) exec ${compiler}/bin/zig "$command" "$@" ;;
              -c|-S|-E|-M|-MM|-fsyntax-only) link=false ;;
              --dynamic-linker|--dynamic-linker=*|-dynamic-linker|--no-dynamic-linker|-Wl,*dynamic-linker*) default_loader=false ;;
            esac
          done
          # The prebuilt compiler cannot discover /usr/bin/env in a Nix build
          # sandbox and otherwise selects musl against the discovered glibc
          # headers. Keep native CPU/OS selection, but make the shell ABI exact.
          native_args=(-target native-native-gnu.${lib.versions.majorMinor stdenv.cc.libc.version})
          # An explicit ABI disables Zig's automatic native path discovery.
          # Forward the same Nix include/library paths as discrete arguments;
          # never evaluate environment contents as shell code.
          read -r -a compile_flags <<< "''${NIX_CFLAGS_COMPILE-}"
          next=""
          for arg in "''${compile_flags[@]}"; do
            if [ -n "$next" ]; then
              native_args+=("$next" "$arg")
              next=""
            else
              case "$arg" in -isystem|-idirafter) next=$arg ;; esac
            fi
          done
          if [ "$link" = true ]; then
            read -r -a link_flags <<< "''${NIX_LDFLAGS-} ''${NIX_CFLAGS_LINK-}"
            next=""
            for arg in "''${link_flags[@]}"; do
              if [ "$next" = -L ]; then
                native_args+=("-L$arg" "-Wl,-rpath,$arg")
                next=""
              elif [ "$next" = -rpath ]; then
                native_args+=("-Wl,-rpath,$arg")
                next=""
              else
                case "$arg" in
                  -L|-rpath) next=$arg ;;
                  -L?*) native_args+=("$arg" "-Wl,-rpath,''${arg:2}") ;;
                esac
              fi
            done
          fi
          if [ "$link" = false ] || [ "$default_loader" = false ]; then
            exec ${compiler}/bin/zig "$command" "''${native_args[@]}" "$@"
          fi
          exec ${compiler}/bin/zig "$command" "''${native_args[@]}" -Wl,--dynamic-linker,${stdenv.cc.bintools.dynamicLinker} "$@"
          ;;
        *) exec ${compiler}/bin/zig "$command" "$@" ;;
      esac
    '';
  in
  symlinkJoin {
    name = "transit-zig-${upstream.version}";
    inherit (upstream) version;
    paths = [ compiler ];
    postBuild = ''
      rm "$out/bin/zig"
      ln -s ${wrapper} "$out/bin/zig"
    '';
    meta = upstream.meta // {
      description = "Pinned Zig with the Nix ELF loader for native Linux builds";
      platforms = lib.platforms.linux;
    };
  }
