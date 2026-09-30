# Development launchers

For an installed local bundle, use `transit server` as described in the
[quickstart](quickstart.md). Repository contributors also use launchers to build
and exercise concrete development deployments. Launchers compose services;
Transit history remains execution authority.

| Placement | Environment | Lifecycle and limits |
| --- | --- | --- |
| Local | Native processes on a trusted development host | Persistent disk state, Board and example workers; shares the local OS account |
| Compose | Containerized services | Persistent volumes and explicit service replacement; requires a container engine |
| Reference | Kubernetes with Agent Substrate | Provider-managed placement with scoped runtime authority; infrastructure has a separate lifecycle |

Each launcher distinguishes building candidate artifacts, updating a deployment
and restarting its selected version. Stopping preserves data; resetting deletes
a stopped installation explicitly. A provider restart cannot grant execution
rights or revive a retired process. Compatible replacement preserves logical
identity and current permissions; incompatible definitions require a hard cutover.

The [repository launcher runbook](../../launchers/README.md) owns setup, commands,
configuration, artifact selection and recovery procedures for these development
systems. [Deployment and recovery](../reference/deployment.md) explains the
runtime boundaries and unsupported recovery cases. The
[proof ledger](../../tests/README.md) records executed placement checks and limits.
