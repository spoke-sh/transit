---
# system-managed
id: VF7qvmhSs
status: done
created_at: 2026-03-27T19:35:45
updated_at: 2026-03-27T19:59:24
# authored
title: Publish Foundational Docs And Deploy Pipeline
type: chore
operator-signal:
scope: VF7qPMy1g/VF7qsOO8T
index: 1
started_at: 2026-03-27T19:52:14
submitted_at: 2026-03-27T19:59:22
completed_at: 2026-03-27T19:59:24
---

# Publish Foundational Docs And Deploy Pipeline

## Summary

Publish the foundational repo contracts through the docs site and add the static deployment path needed to ship the site to S3 and CloudFront.

## Acceptance Criteria

- [x] [SRS-04/AC-01] Add a repeatable sync step that publishes selected foundational repo Markdown documents into the website docs tree. <!-- [SRS-04/AC-01] verify: bash -lc 'cd .. && just docs-sync', SRS-04:start, SRS-04:end, proof: ac-1.log -->
- [x] [SRS-05/AC-01] Add a deployment workflow that builds the docs site and supports S3 sync plus CloudFront invalidation from repository-provided configuration. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] Ensure the docs site can build from the repo without manual copying of foundational documents into `website/`. <!-- [SRS-NFR-02/AC-01] verify: bash -lc 'cd .. && just docs-build', SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->
