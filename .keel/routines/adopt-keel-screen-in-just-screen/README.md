---
id: adopt-keel-screen-in-just-screen
title: Adopt Keel Screen In Just Screen
cadence:
  cron: "0 9 1 * *"
  timezone: America/Los_Angeles
  trigger: keel-upgrade
target-scope: VDd1J2IDM
created_at: 2026-03-12T20:05:04
updated_at: 2026-03-12T20:05:04
---

# Blueprint

- Trigger this routine on every `keel` upgrade or whenever the operator-facing `Justfile` recipes change.
- Check whether `keel screen` is now a supported command and whether it is stable enough to replace the current `keel flow` fallback in `just screen`.
- If `keel screen` exists, update `Justfile` so `just screen` calls it directly, remove the compatibility probe, refresh the docs, and verify the board output remains clean and useful.
- Exit only when the preferred `keel` screen command is wired into the human-facing recipe or the fallback remains explicitly justified in the commit or change notes.
