{
  lib,
  buildGoModule,
  fetchFromGitHub,
  runCommand,
  transit,
  ursula,
}:
let
  # Same release as the local server's disk/S3 fixture. Build from pinned source
  # because upstream no longer distributes the historical executable/image.
  minio = buildGoModule {
    pname = "transit-local-minio";
    version = "2025-09-07T16-13-09Z";
    src = fetchFromGitHub {
      owner = "minio";
      repo = "minio";
      rev = "RELEASE.2025-09-07T16-13-09Z";
      hash = "sha256-0IVxxeM+h3josP+wnS3q4Nrmd3fT9V+KlHxlwz3QyIQ=";
    };
    vendorHash = "sha256-JrDLUVGtwYqwwB+Suutewi6snHyIpG3DOnDn5O0C+L0=";
    subPackages = [ "." ];
    env.CGO_ENABLED = 0;
    doCheck = false;
    ldflags = [
      "-s"
      "-w"
      "-X github.com/minio/minio/cmd.Version=2025-09-07T16:13:09Z"
      "-X github.com/minio/minio/cmd.ReleaseTag=RELEASE.2025-09-07T16-13-09Z"
    ];
    meta = {
      description = "Pinned MinIO executable for Transit's local development profile";
      license = lib.licenses.agpl3Plus;
      platforms = [ "x86_64-linux" ];
    };
  };
in
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
