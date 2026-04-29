{ pkgs
, version ? "0.0.0-20260429181921-cb2889780c8d"
}:

pkgs.buildGoModule {
  pname = "scion";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "GoogleCloudPlatform";
    repo = "scion";
    rev = "cb2889780c8da9a4dd5db669f729f16ded943c67";
    hash = "sha256-mx43UPbJJY8RowScqMNAUmUvGkZVZrK+FwXQKAGggYY=";
  };

  subPackages = [ "cmd/scion" ];

  vendorHash = "sha256-SC+TKN2Zkr166vkHA+14CvhM6wPZI/DWpbCRRHmON9Q=";
}
