# ADR-0005: Delegate the owner's approvals for the Daily reader milestone

- Date: 2026-11-27
- Status: Accepted

## Context

ADR-0001 says no change merges without a human looking. The owner is away and asked one Claude Code session, the orchestrator, to run the Daily reader milestone: start the spec author, reviewer, and implementer sessions, publish approved specs, and merge.

## Decision

Until the Daily reader milestone closes or the owner says otherwise, the orchestrator acts for the owner:

- It publishes a `spec/<branch>` only after a reviewer session reported on that exact commit, and merges a PR only after a reviewer session reported on its exact head and CI passed.
- It answers questions the spec author would ask the owner, and records each such design decision in a log the owner reads on return.
- It never writes specs, tests, or implementation itself.
- Checks that need the owner's own iPhone (#19, #22) wait for the owner.

## Consequences

- Changes reach `main` without a human looking until the owner returns; the owner reviews the decision log and the merged PRs, and reverts or supersedes what they disagree with.
- Every merge still has a reviewer's report pinned to its SHA, so what was approved stays traceable.
