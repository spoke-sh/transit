# Transit BEAM native Station artifact

Version 0.2.0 is a separate OTP application containing the shared Zig Station
host in `priv/transit-station-host`. It requires Linux x86_64 and the pinned Nix
closure. Public SDKs discover it through ordinary OTP application resolution and
check package/host versions. Loading the application starts no native process,
authority access or signing. Both public Station APIs pass the shared M11 authority schedule.
