# INSTRUCTIONS.md

Procedural instructions for agents and operators working on `transit`.

## Tactical Loop

Every session should follow the same control loop:

1. **Mission Orientation**: Run `just keel mission next --status` and `just keel flow --scene` to see whether the board is autonomous, idle, or waiting on human input.
2. **Role Selection**: Stay in one role for one atomic change. Use manager mode for planning and acceptance. Use operator mode for implementation and evidence.
3. **Execute One Move**: Perform one tactical move at a time: fix doctor drift, plan a voyage, implement a story, or close a lifecycle transition.
4. **Seal The Move**: Use the matching lifecycle command such as `just keel story submit`, `just keel voyage plan`, `just keel voyage done`, or `just keel bearing lay`.
5. **Log And Commit**:
   - Record the move in the relevant mission `LOG.md` when the change is mission-scoped.
   - Refresh the pacemaker with `just keel poke "Sealing move: <summary>"` before committing.
   - Commit once per logical unit. The installed pre-commit hook runs `just quality` and `just test` automatically.
6. **Re-Orient**: After the commit lands, run `just keel doctor --status` and `just keel flow` before choosing the next move.

## Human Interaction

When a human opens chat or explicitly pokes the system:

1. Run `just keel poke "Human interaction in chat"`.
2. Run `just keel health --scene`.
3. Run `just keel mission next --status` and `just keel pulse`.
4. Run `just keel flow --scene`.
5. Run `just keel doctor`.

Do not ask the human for input until you have completed that orientation and resolved any doctor failures that are safely actionable inside the repo.

## Global Hygiene

Apply these checks to every change:

1. **Doctor First**: `just keel doctor` is the source of truth for board integrity.
2. **Pacemaker Protocol**: Any unit of work that mutates the board should end with a committed `.keel/heartbeat`.
3. **Automated Guardrails**: Do not manually duplicate `just quality` or `just test` before every commit unless you need early feedback; the pre-commit hook enforces them.
4. **Lifecycle Before Commit**: Run story, voyage, epic, or bearing lifecycle commands before the atomic commit so generated `.keel` artifacts land in the same change.
5. **Atomic Commits**: Keep one logical story, planning slice, or maintenance change per commit.
6. **Mission Loop Discipline**: After each completed move, return to `mission next`, `doctor`, and `flow` rather than continuing ad hoc.

## Command Model

Use one path per concern:

- `just ...` for repo build, test, proof, and helper commands.
- `just keel ...` for board and workflow operations through the pinned keel flake input.

Common commands:

- `just screen`: default human proof path
- `just quality`: formatting and clippy checks
- `just test`: workspace tests
- `just keel doctor`
- `just keel mission next --status`
- `just keel flow --scene`
- `just keel hooks install`

## Upgrade Rule

When upgrading the `keel` input:

1. Update `flake.lock`.
2. Build the new `keel`.
3. Install hooks with `just keel hooks install`.
4. Reconcile any upstream workflow changes from `~/workspace/spoke-sh/keel/AGENTS.md` and `~/workspace/spoke-sh/keel/INSTRUCTIONS.md` into this repo's `AGENTS.md`, `INSTRUCTIONS.md`, `Justfile`, and related docs.
5. Run the human-interaction orientation loop and clear doctor issues before reporting status back to the user.
