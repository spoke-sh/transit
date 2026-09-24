# Pinned Substrate CLI extension

`reference-tools.nix` adds these two Go files to the external upstream CLI at
the pinned Substrate revision. They expose the server's existing `UpdateActor`
API as `kubectl ate update actor`. No Substrate server API changes are required.

The binary reports `transit-upgrade-v1` as its version and retains the upstream
base commit separately. This is a local packaged extension, not an upstream
release. Its tests run during the Nix build. Remove it when a reviewed upstream
CLI supplies an equivalent guarded operation; do not silently change its profile.

The command requires the expected Actor UID, previous template and target
template in the same atespace. It fetches the current resource, requires suspended
state, preserves other fields and sends the fetched UID/version as server
preconditions. It does not retry conflicts. A matching target is an idempotent
readback, still subject to UID and stopped-state checks.

Transit must record upgrade authority before invoking this command. Provider
credentials alone are not Transit execution authority. See the
[runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md).
