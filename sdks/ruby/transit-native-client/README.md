# transit-native-client for Ruby

Version-matched Linux x86_64 and ARM64 native port artifact for the independent Ruby client.
The package builder supplies `native/transit-client-host`; no executable is kept
in Git. Loading the gem only exposes its path and version. The packaged executable
requires the pinned Nix runtime closure. Registry publication and other platforms
remain outside the qualified baseline.
