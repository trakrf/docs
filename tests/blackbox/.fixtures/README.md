# `.fixtures/` — fixture-maintenance SQL landing zone

Persistent, gitignored landing zone for SQL scripts produced while maintaining the BB parallel-fixture orgs (`BB1`, `BB2`, `BB3`) against the preview database. Files here survive reboots and worktree churn but are deliberately kept out of git — they're operational records, not contract.

## What lives here

- **One-shot cleanup scripts** produced during BB cycles when fixture drift is observed and reversed (cruft assets from prior cycles, stale probe values, seed typos). Naming convention: `bb<NN>-<short-tag>.sql`, e.g. `bb57-cleanup.sql`.
- **Reusable diagnostic SQL** that doesn't belong in the published docs build but is worth keeping reachable.

## What does _not_ live here

- The original seed SQL for the fixture orgs — that's owned by the platform side (originally `/tmp/bb-migration.sql` from the seed cycle).
- Any SQL that would mutate non-fixture data.

## Why gitignored

The cleanup scripts are tied to specific point-in-time drift observations. Committing them would create a misleading impression that they're a maintained seed; they're not — they're forensic. The published seed lives upstream.

This directory is referenced from BB cycle handoff notes ("SQL persisted to `tests/blackbox/.fixtures/`") so collaborators know where to look. The `.gitignore` rule keeps file contents out of the repo while letting this README document the convention.
