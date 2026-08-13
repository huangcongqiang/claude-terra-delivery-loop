---
name: claude-terra-delivery-loop
description: Orchestrate high-confidence software delivery with a Claude Code implementation worker, independent Terra review lenses, Codex-owned fixes, repeated review-fix gates, diff-scope enforcement, and final verification. Use for multi-step coding, API/schema, architecture, or UI implementation tasks when the user asks to use Claude, Terra or subagents, LoopX or long-running execution, review-fix until clean, strict Figma/demo/reference fidelity, or protection against workers returning no diff or drifting outside scope.
---

# Claude + Terra Delivery Loop

Run one bounded implementation task through an evidence-based delivery loop:

`task packet → Claude implementation → actual diff inspection → independent Terra reviews → Codex fix → full re-review → verification → writeback/cleanup`

Keep the main agent as the only delivery owner. Never treat a worker or reviewer summary as proof.

## Respect the host project

1. Read all applicable `AGENTS.md`, task cards, plans, repository instructions, and named skills before acting.
2. Treat local rules, the user request, and source-of-truth artifacts as higher priority than this workflow.
3. Use this skill inside an existing LoopX program when present; do not create a second task registry. Update LoopX only after verified writeback.
4. For trivial, tightly coupled changes, let the main agent implement directly and retain the review/verification gates.

## Apply the Ponytail solution gate

Load the installed `ponytail` skill for every coding task. Respect an explicit user intensity; otherwise use `full`. After reading the complete affected flow, choose the first sufficient rung: prove no change is needed, reuse existing code, use the standard library, use a native platform feature, use an already-installed dependency, use one direct line, or add the minimum new code. For bug fixes, inspect every caller and fix the root cause once at the shared owner rather than patching only the reported symptom.

Record the selected intensity, rung, non-goals, and any deliberate ceiling/upgrade trigger in the existing task packet; do not create another artifact or lifecycle. A deliberate simplification with a real ceiling requires a `ponytail:` comment naming the ceiling and upgrade trigger. Non-trivial logic must leave one minimal runnable regression check; it supplements rather than replaces project-required validation. Reject speculative abstractions, dependencies, configuration switches, compatibility layers, scaffolding, and documentation. Ponytail controls solution size only: it must not weaken explicit functionality, security, authorization, validation, accessibility, data integrity, business/state invariants, recovery, rollback, or required verification. If the baseline already satisfies acceptance, prove it before dispatch instead of manufacturing a diff.

## 1. Freeze the task packet

Before dispatching, record:

- one concrete objective and the observable acceptance result;
- Ponytail intensity, first sufficient solution rung, explicit non-goals, any deliberate ceiling/upgrade trigger, and the one minimal runnable check required for non-trivial logic;
- authoritative task/spec/design files;
- allowed files or path globs and explicit forbidden areas;
- source-of-truth UI references such as Figma node/page, screenshots, or demo project paths;
- non-goals and prohibited actions such as commit, push, deploy, dependency upgrades, broad formatting, or deletion;
- required verification commands and severity gate;
- dirty baseline, current revision, and isolation strategy.

Read [references/task-packets.md](references/task-packets.md) when composing worker or reviewer prompts.

Do not dispatch an ambiguous package. Split it when different subtasks need different source-of-truth inputs, owners, or verification commands. Split again when a worker cannot finish within one bounded implementation session.

## 2. Establish a recoverable baseline

Inspect the real workspace before delegation:

- enumerate relevant files with `rg`/`rg --files`;
- record existing user changes and never mix or overwrite them;
- use a task-specific worktree or temporary Git snapshot when the source root is dirty, non-Git, or shared with other work;
- record baseline revision and, when useful, hashes of files that will later be integrated;
- define how the isolated result will be compared and applied to the main workspace.

Never use destructive Git commands. Never let the worker commit, push, deploy, or modify the main workspace unless the task explicitly authorizes it.

## 3. Delegate implementation to Claude

When Claude implementation is requested or required by project rules, load and follow the installed `claude-code-dispatcher` skill. Use one worker by default.

Give Claude the frozen task packet, including exact working directory, allowed paths, authoritative artifacts, Ponytail solution contract, constraints, acceptance criteria, and verification commands. Require it to inspect the complete affected flow before editing and to report the actual changed paths and command results.

Do not use motivational or pressure prompts as a control mechanism. Narrow the task and make evidence requirements explicit.

If Claude is unavailable, let the main agent take over or report the blocker. Do not silently replace a required Claude implementation worker with a built-in subagent.

## 4. Poll without reconnect loops

- Prefer bounded progress checks over long blocking waits.
- Do not repeatedly reconnect to a completed or missing session.
- After two unchanged checks, inspect terminal/session state and determine whether the worker is running, waiting for input, finished, or stalled.
- Interrupt and recover a stalled worker before starting another worker.
- Keep user-facing status updates concise and no farther than the host environment permits.

## 5. Inspect the actual diff

After the worker stops, independently inspect the filesystem and diff before reading its conclusion.

Run the bundled scope gate inside the worker Git snapshot:

```bash
ruby /path/to/claude-terra-delivery-loop/scripts/check_delivery_diff.rb \
  --repo /path/to/worker-repo \
  --base BASELINE_SHA \
  --allow 'design/api/**' \
  --expect 'design/api/openapi.yaml'
```

The gate fails on an empty diff, out-of-scope paths, deletions by default, or `git diff --check` errors. Repeat `--allow` and `--expect` as needed; pass `--allow-delete` only when deletion is explicitly in scope.

Git does not report ignored files through the normal diff/untracked surfaces. If and only if the task explicitly authorizes one ignored regular file, record its pre-worker SHA-256 (or `ABSENT`) and pass it as exact `--allow-ignored 'path=baseline'`; also include that exact path in `--allow`/`--expect` when required. The checker rejects ignored directories and globs. Never authorize dependency/build trees or secret files this way.

Always pass the immutable baseline revision recorded before the worker starts. Do not substitute the worker's current `HEAD`, because an unauthorized worker commit could otherwise hide its changes.

Then inspect the changed content, not only filenames or statistics. Confirm:

- the requested behavior exists in code or contract;
- no unrelated formatting, dependency, import, or generated-file churn was mixed in;
- the implementation used the first sufficient solution rung without speculative abstraction, configuration, or scaffolding;
- worker verification really ran against the changed workspace;
- reference UI/demo structure remains aligned when applicable.

### Empty-diff recovery

If Claude reports success but produces no diff:

1. Determine whether the baseline already satisfies the acceptance criteria.
2. Verify the worker directory, revision, permissions, session output, and whether it edited another worktree.
3. Retry once with a smaller objective, exact target file, and the first failing assertion or missing observable.
4. If the second bounded attempt still produces no diff, let the main agent implement or report a real blocker. Never perform a fictional review of unchanged code.

## 6. Run independent Terra reviews

Use independent read-only reviewers only through mechanisms allowed by the applicable host/project rules. When built-in subagents are allowed, prefer three independent lenses for high-risk or cross-layer work:

1. **Domain/state lens** — invariants, state owner, transitions, authorization, idempotency, concurrency, side effects, historical facts.
2. **Schema/integration lens** — API/schema validity, runtime semantics, code generation, compatibility, call-site chain, error exits, migrations.
3. **Delivery/reference lens** — task scope, tests, regression risk, UI/Figma/demo fidelity, missing states, unjustified abstractions/dependencies/scaffolding, cleanup and rollback.

Give each reviewer raw artifacts and task-local context, not prior findings or the intended answer. Require file/line evidence and only actionable P0/P1/P2 findings. Reviewers must not edit files.

If built-in reviewers are disallowed or Terra is unavailable, keep Claude implementation through `claude-code-dispatcher`, then use an allowed independent read-only reviewer or primary-agent review and disclose the substitution. If concurrency is limited, run the lenses serially.

## 7. Fix under Codex ownership

Verify each finding against source before accepting it. Fix the root cause with the smallest in-scope change, then run the narrowest relevant check immediately.

Do not ask Claude to make every correction automatically. Use Claude again only when the fix is bounded and benefits from terminal implementation; keep highly coupled or judgment-heavy corrections with the main agent.

Treat severity as follows:

- **P0**: data loss, security breach, irreversible external impact, or fundamentally unusable delivery — stop integration.
- **P1**: invalid core behavior, impossible schema/state, broken authorization/idempotency, or failed required build/test — must fix.
- **P2**: material edge case, inconsistent contract, missing error path, unstable projection, or meaningful reference drift — must fix before clean gate.
- **P3**: optional improvement — record without expanding scope unless requested.

## 8. Repeat to a clean gate

After any P0/P1/P2 fix:

1. rerun narrow validation;
2. rerun affected review lenses;
3. finish with one full review of the latest candidate, not only an incremental check;
4. require the latest full round to contain no known P0/P1/P2.

Do not claim clean status merely because earlier findings were addressed.

## 9. Integrate and verify independently

Before applying isolated changes, recheck that main-workspace baseline files still match the recorded hashes or revision. Stop on overlap with unknown user changes.

Apply only the reviewed diff using the host project's approved editing mechanism. Verify isolated and integrated artifacts byte-for-byte when practical.

Run, in proportion to risk:

- focused unit/contract tests;
- lint and format checks without broad rewrites;
- build or type generation;
- schema/parser/runtime validation;
- duplicate-key, reference, or migration checks;
- UI comparison against the named Figma/demo references;
- the project's full relevant validation suite.

Separate new failures from known baselines with evidence. Do not fix unrelated baselines without authorization.

## 10. Write back and clean up

Only after successful integrated verification:

- update the authoritative task card with changed files, review-fix rounds, commands, results, impact, rollback, remaining risks, and next task;
- update LoopX/task state exactly once when applicable;
- remove or recoverably trash temporary snapshots, generated types, logs, sessions, workers, and worktrees;
- verify no worker or process remains active;
- report the outcome, validation, impact, known baseline issues, and resource state.

Do not mark the outer long-running goal complete if verified successor work remains.
