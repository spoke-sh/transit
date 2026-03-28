---
# system-managed
id: VF7qvnxSu
status: done
created_at: 2026-03-27T19:35:45
updated_at: 2026-03-27T19:44:46
# authored
title: Scaffold Transit Docusaurus Site
type: feat
operator-signal:
scope: VF7qPMy1g/VF7qsOO8T
index: 3
started_at: 2026-03-27T19:38:07
submitted_at: 2026-03-27T19:44:38
completed_at: 2026-03-27T19:44:46
---

# Scaffold Transit Docusaurus Site

## Summary

Create the first `website/` workspace for Transit using Docusaurus, including a public home page, docs navigation, custom transport-native styling, and the basic local build commands needed to work on the site.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Create a Docusaurus workspace under `website/` with package metadata, config, sidebar, homepage, and base doc structure for the Transit public site. <!-- [SRS-01/AC-01] verify: nix shell nixpkgs#nodejs_20 --command bash -lc 'cd .. && npm --prefix website run build', SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-NFR-03/AC-01] Establish a distinct Transit visual identity with a transport/railroad design language instead of the default Docusaurus theme. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-2.log -->
