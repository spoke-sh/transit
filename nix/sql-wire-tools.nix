{ pkgs }:
# Independent database servers and clients. The existing flake.lock fixes their
# sources; the Python connector wheel is pinned separately. No query engine here
# is a Transit runtime dependency.
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
assert pkgs.postgresql_18.version == "18.6";
assert pkgs.mysql84.version == "8.4.11";
assert pkgs.openssl.version == "3.6.4";
assert pkgs.python3Packages.psycopg.version == "3.3.4";
let
  connector = pkgs.python3Packages.buildPythonPackage {
    pname = "mysql-connector-python";
    version = "9.4.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/36/34/b6165e15fd45a8deb00932d8e7d823de7650270873b4044c4db6688e1d8f/mysql_connector_python-9.4.0-py2.py3-none-any.whl";
      sha256 = "56e679169c704dab279b176fab2a9ee32d2c632a866c0f7cd48a8a1e2cf802c4";
    };
    pythonImportsCheck = [ "mysql.connector" ];
  };
in
{
  packages = [
    pkgs.postgresql_18
    pkgs.mysql84
    pkgs.pkg-config
    pkgs.openssl.dev
    (pkgs.python3.withPackages (
      ps:
      (import ./python-tools.nix ps)
      ++ [
        ps.psycopg
        connector
      ]
    ))
  ];
  openssl = pkgs.openssl;
}
