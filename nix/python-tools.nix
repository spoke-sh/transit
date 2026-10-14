# Common proof dependencies. Optional shells extend this interpreter instead of
# shadowing it with an environment missing the native suite's Python modules.
ps: [
  ps.pyyaml
  ps.jsonschema
  ps.pyarrow
  ps.grpcio
  ps.protobuf
  ps.h2
  ps.build
  ps.setuptools
  ps.wheel
  ps.pip
  ps.mypy
]
