---
# system-managed
id: VIEYQVGWX
status: done
created_at: 2026-04-29T18:32:47
updated_at: 2026-04-29T18:34:01
# authored
title: Fix Justfile Passthrough Argument Quoting
type: bug
operator-signal:
started_at: 2026-04-29T18:32:53
completed_at: 2026-04-29T18:34:01
---

# Fix Justfile Passthrough Argument Quoting

## Summary

Preserve argument boundaries in the Justfile passthrough recipes so quoted CLI
arguments reach the underlying binaries unchanged.

## Acceptance Criteria

- [x] [SRS-NFR-03/AC-01] `just transit` preserves a quoted SQL command containing `*` as one command argument instead of allowing shell glob expansion. <!-- [SRS-NFR-03/AC-01] verify: just transit sql --root target/keel-proof/VIEYQVGWX/sql --row alpha=1 --row beta=2 -c 'SELECT * FROM transit.public.tasks', SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-1.log-->
