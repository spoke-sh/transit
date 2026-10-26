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
          for arg in "$@"; do
            case "$arg" in
              --) break ;;
              -target|--target|-target=*|--target=*|--dynamic-linker|--dynamic-linker=*|--no-dynamic-linker|-dynamic-linker|-Wl,*dynamic-linker*)
                exec ${compiler}/bin/zig "$command" "$@"
                ;;
            esac
          done
          # In a Nix build sandbox the static upstream compiler cannot inspect
          # a host executable to infer the libc ABI. These native C drivers
          # consume the shell's GNU libc headers/libraries, including libc++.
          exec ${compiler}/bin/zig "$command" -target native-native-gnu.${lib.versions.majorMinor stdenv.cc.libc.version} -Wl,--dynamic-linker=${stdenv.cc.bintools.dynamicLinker} "$@"
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
