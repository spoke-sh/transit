---
# system-managed
id: VIEbdXaJd
status: done
created_at: 2026-04-29T18:45:32
updated_at: 2026-04-29T18:49:31
# authored
title: Make Consume Tail By Default
type: bug
operator-signal:
started_at: 2026-04-29T18:45:33
completed_at: 2026-04-29T18:49:31
---

# Make Consume Tail By Default

## Summary

Make `transit consume` tail live records from the current hosted stream head
when `--from-offset` is omitted, while preserving explicit bounded replay when
`--from-offset` is provided.

## Acceptance Criteria

- [x] [SRS-02/AC-01] `transit consume --stream-id <id>` tails records appended after the command starts instead of replaying from offset `0`. <!-- [SRS-02/AC-01] verify: cargo test -p transit-cli consume_defaults_to_live_tail_from_current_head -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-1.log-->
- [x] [SRS-02/AC-02] Explicit `--from-offset 0` still provides bounded replay from the beginning. <!-- [SRS-02/AC-02] verify: cargo test -p transit-cli streams_produce_and_consume_cover_the_kcat_style_remote_flow -- --nocapture, SRS-02:continues, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] Runtime data from the default `.transit/` root no longer creates source-control drift. <!-- [SRS-NFR-03/AC-01] verify: git check-ignore .transit/data/streams/foo/state.json, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
- [x] [SRS-NFR-03/AC-02] User-facing docs describe omitted `--from-offset` as live tailing and explicit `--from-offset 0` as replay. <!-- [SRS-NFR-03/AC-02] verify: root=$(git rev-parse --show-toplevel) && rg -n 'Omit .*--from-offset' "$root/USER_GUIDE.md" "$root/website/docs/start-here/server-first-run.mdx" && rg -n 'bounded replay' "$root/USER_GUIDE.md" "$root/website/docs/start-here/server-first-run.mdx", SRS-NFR-03:continues, SRS-NFR-03:end, proof: ac-4.log-->
