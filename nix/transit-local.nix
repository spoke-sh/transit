{
  runCommand,
  transit,
}:
runCommand "transit-local-${transit.version}"
  {
    passthru = {
      inherit transit;
    };
    meta = {
      description = "Transit local server and SQL console in one executable";
      mainProgram = "transit";
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    mkdir -p "$out/bin"
    cp ${transit}/bin/transit "$out/bin/transit"
  ''
