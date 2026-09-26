# transit-client for Ruby

Independent value objects, opaque native retry material and block-scoped clients
over the shared Zig port. Protocol signing, canonical recovery and authority
checks remain in Zig. The raw client has no Station dependency.

Build/install with the pinned Ruby 3.4.9 toolchain:

```sh
nix develop .#bindings
just bindings::ruby-build
gem install --local --user-install .cache/bindings/ruby/*.gem
```

`require 'transit/client'` loads definitions only. Read the
[usage and recovery guide](docs/USAGE.md) for block ownership, errors and retry
material. The separate [native gem](../transit-native-client/README.md) supplies
its executable without a manual loader path; its Nix runtime closure must remain
available. An explicit `native_host` can select a trusted compatible executable.
Registry publication, other Ruby versions and other platforms remain unqualified.

`nix develop .#bindings --command just bindings::ruby-sdk-test` installs both gems
outside the checkout and runs the shared raw authority schedule, malformed port
responses, bounded admission and caller interruption/cleanup. See the
[test guide](../../../tests/README.md). The separate [Station gem](../transit-station/README.md) adds scoped handlers and state.
