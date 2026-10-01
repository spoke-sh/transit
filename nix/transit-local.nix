{
  minio,
  runCommand,
  transit,
  ursula,
}:
runCommand "transit-local-0.1.0"
  {
    passthru = { inherit transit ursula minio; };
    meta = {
      description = "Transit local neighborhood artifacts and executable manifest";
      mainProgram = "transit";
      platforms = [ "x86_64-linux" ];
    };
  }
  ''
    mkdir -p "$out/bin" "$out/share/transit"
    ln -s ${transit}/bin/* "$out/bin/"
    # A real executable keeps adjacent dependency discovery tied to this bundle,
    # including invocations through PATH and symlinks outside the Nix store.
    rm "$out/bin/transit"
    cp ${transit}/bin/transit "$out/bin/transit"
    ln -s ${minio}/bin/minio "$out/bin/minio"
    ln -s ${ursula}/bin/ursula "$out/bin/ursula"
    cat > "$out/share/transit/local-executables.json" <<EOF
    ${builtins.toJSON {
      minio = "${minio}/bin/minio";
      ursula = "${ursula}/bin/ursula";
      node = "${transit}/bin/transit-node";
      query_host = "${transit}/bin/transit-query-host";
      board = "${transit}/bin/transit-board";
    }}
    EOF
  ''
