{ pkgs }:
# Independent M22 clients. These wheels are client tooling, never linked into
# the Zig gateway/engine. Other platforms require separately reviewed pins.
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
assert pkgs.python3.pythonVersion == "3.13";
let
  ps = pkgs.python3Packages;
  manager = ps.buildPythonPackage {
    pname = "adbc-driver-manager";
    version = "1.12.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/00/c6/a35e38ef5e0db391be79e0e14c019ce378b87d9d7e31d1dfcd451e9d291f/adbc_driver_manager-1.12.0-cp313-cp313-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      sha256 = "532ab290b3d923ce0a75bca21dc6e13f55835625f78808e1664755939f3ebdf6";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dependencies = [ ps.typing-extensions ];
    pythonImportsCheck = [ "adbc_driver_manager" ];
  };
  driver = ps.buildPythonPackage {
    pname = "adbc-driver-flightsql";
    version = "1.12.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/2b/5b/f8566aa6d05eb40225f5874f8f5f5e8b8b4a4ce866d817a5ff352f326302/adbc_driver_flightsql-1.12.0-py3-none-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      sha256 = "69742e4f8fcc254490aa7f8e254a3b704c24bde9d5d827a0926ea90a6b4c3a6d";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    dependencies = [
      manager
      ps.importlib-resources
    ];
    pythonImportsCheck = [ "adbc_driver_flightsql" ];
  };
in
pkgs.python3.withPackages (ps: [
  driver
  manager
  ps.pyarrow
  ps.grpcio
  ps.protobuf
  ps.h2
  ps.pyyaml
  ps.jsonschema
])
