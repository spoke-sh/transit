{ pkgs }:
{
  packages = with pkgs; [
    go
    rustc
    cargo
    patchelf
    binutils
    rustfmt
    ruby
    jdk
    tlaplus
    dotnet-sdk
    erlang
    beam.packages.erlang_28.elixir
  ];
  gson = pkgs.fetchurl {
    url = "https://repo.maven.apache.org/maven2/com/google/code/gson/gson/2.12.1/gson-2.12.1.jar";
    sha256 = "1v7vnk63b7ppjzd4hlki143si36zav1y04603izwsxvlzgai7vpb";
  };
  gsonLicense = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/google/gson/gson-parent-2.12.1/LICENSE";
    hash = "sha256-z8d0m5b2O9McPEK1xHG/dWgUBT6EfBDz6wA0F7xSPTA=";
  };
}
