# Shared independent test inputs

| Input family | Consumers and provenance |
| --- | --- |
| [gRPC](grpc/README.md) | Reviewed service definitions and separately generated wire fixtures for the gRPC checks |
| [Reactive descriptions](reactive/README.md) | Pinned upstream OpenAPI/AsyncAPI validation schemas, licenses and hashes |

Follow [fixture instructions](AGENTS.md) when changing these inputs. Executable
oracles belong with the domain they check. Contract-owned vectors remain with
their contract or package; fixture availability does not establish a passed test.
