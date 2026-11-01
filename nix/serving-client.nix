{ transit }:
transit.overrideAttrs (_: {
  pname = "transit-serving-client";
  buildPhase = ''
    runHook preBuild
    zig build transit-serving-client --system ${transit.zigDependencies} -Dchecks=false -Doptimize=ReleaseSafe -Dcpu=baseline -j$NIX_BUILD_CORES --prefix "$out"
    runHook postBuild
  '';
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/transit-serving-client"
    if "$out/bin/transit-serving-client" </dev/null >result 2>error; then
      exit 1
    fi
    test ! -s result
    runHook postInstallCheck
  '';
})
