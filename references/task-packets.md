# Task packet and review prompts

Load this reference only when preparing a Claude worker or independent review prompt.

## Implementation packet

```text
Objective
- <one observable result>

Workspace
- Work only in: <absolute isolated path>
- Baseline: <revision/hash>

Authoritative inputs
- <task card/spec>
- <code/schema entrypoints>
- <Figma node/demo/screenshot when applicable>

Allowed changes
- <exact files or globs>

Forbidden changes
- No commit/push/deploy/dependency upgrade/broad formatting.
- Do not edit <unrelated or user-owned paths>.

Acceptance
- <behavioral and structural checks>
- <reference-fidelity checks>

Verification
- <exact commands>

Return
- Actual changed paths, concise rationale, command outputs, risks, and blockers.
- Do not report completion without a real filesystem diff unless the baseline already passes every acceptance check; prove that case explicitly.
```

## Domain/state reviewer

```text
Perform a read-only review of the current candidate against the authoritative task/spec.
Inspect the actual source and diff. Check invariants, state ownership, transitions,
authorization, idempotency, concurrency, side effects, historical facts, and rollback.
Do not modify files. Report only actionable P0/P1/P2 findings with tight file/line evidence;
if none remain, say so explicitly.
```

## Schema/integration reviewer

```text
Perform a read-only review of the current candidate against the authoritative task/spec.
Inspect runtime schema semantics, generated types, compatibility, request/response/error exits,
call-site or migration chains, validation commands, and cross-layer consistency.
Do not modify files. Report only actionable P0/P1/P2 findings with tight file/line evidence;
if none remain, say so explicitly.
```

## Delivery/reference reviewer

```text
Perform a read-only delivery review of the current candidate against the task packet and named
source-of-truth references. Check scope, regression risk, tests, missing loading/empty/error/permission
states, Figma/demo structure and layout fidelity when applicable, cleanup, and recovery.
Do not modify files. Report only actionable P0/P1/P2 findings with tight file/line evidence;
if none remain, say so explicitly.
```

## Final full review

Use the same raw task packet and latest artifacts. Do not include the earlier defect list or tell the reviewer what was fixed. Ask for a complete review, not confirmation of expected fixes.
