{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
# One pinned native provider for local bundles and disk/S3 proof fixtures.
buildGoModule {
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
}
