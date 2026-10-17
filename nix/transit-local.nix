{
  minio,
  runCommand,
  transit,
  transit-sql-gateway,
  ursula,
}:
runCommand "transit-local-0.1.0"
  {
    passthru = {
      inherit
        transit
        transit-sql-gateway
        ursula
        minio
        ;
    };
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
    ln -s ${transit-sql-gateway}/bin/transit-sql-gateway "$out/bin/transit-sql-gateway"
    cat > "$out/share/transit/local-executables.json" <<EOF
    ${builtins.toJSON {
      minio = "${minio}/bin/minio";
      ursula = "${ursula}/bin/ursula";
      node = "${transit}/bin/transit-node";
      query_host = "${transit}/bin/transit-query-host";
      board = "${transit}/bin/transit-board";
      sql_gateway = "${transit-sql-gateway}/bin/transit-sql-gateway";
    }}
    EOF
  ''
