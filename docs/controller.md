# Supervised local development controller

Python 3.11+ and SQLite, standard library only. State operations/tests support macOS/Linux; real agent execution currently requires macOS with the existing `sandbox-exec` utility. Run one explicit command at a time from a **trusted controller checkout separate from every task checkout**. Nothing runs in the background. The controller never pushes, creates PRs, merges, formally approves a PR, publishes releases or deploys. Product databases and services are unrelated to its local task state.

All mutating commands require `--execute`. Approval additionally requires the displayed SHA-256 digest via `--ack`. Without `--execute`, commands do not create state or invoke models/network. `status` reads recorded evidence only, without claiming that GitHub or a checkout has just been revalidated. `capabilities` reports previously observed client profiles; it does not spend quota probing availability.

The operator, configuration files and controller code are trusted. Local acknowledgement is **not GitHub identity authentication**. Issue text cannot create approvals. This is a supervised coordinator, not a sandbox against a malicious same-user process: provider clients retain their existing login access, while agent responses are tool-disabled patch proposals. A per-process fork-denial sandbox prevents detached child processes; it does not isolate every same-user file or credential. Never put credentials in specifications, copy provider tokens, or run unreviewed public tasks. No personal credentials are distributed to CI. Keep the controller source at a reviewed commit; candidate work cannot share that checkout.

## Local setup

Choose one persistent directory outside all repositories, and use it for both projects. The global per-user lock in the OS temporary directory binds this host to that state root and prevents simultaneous invocations, including attempts with a second database. The SQLite database is authoritative across restarts; back it up with its logs while no invocation is running. Do not delete/reset state to clear a hold or correction budget. The host lock is local to this Mac, not a multi-machine lease; do not copy the database between running machines. A reboot can remove the OS temporary lock; continue using the same authoritative state root.

From this trusted controller checkout:

```sh
export PYTHONPATH="$PWD/tools"
export PYTHONDONTWRITEBYTECODE=1
python3 -m voca_controller --state-dir /absolute/local-controller-state capabilities
python3 -m voca_controller --state-dir /absolute/local-controller-state register --config /absolute/projects.json
# Inspect the projects and digest, then repeat with --ack <digest> --execute.
```

The local `projects.json` schema is an object keyed only by `voca` and optionally `arena`. Each record has `repo_name` (owner/repository), numeric `repo_id`, boolean `private`, boolean `execution_enabled`, and `hold_reason`. Voca's public identity is pinned to `MohammedA47/Voca`, ID `1219099434`, `private:false`. Its enabled value is a local operator decision. Arena's exact verified identity stays in the private local configuration, not this public repository. Arena must have `private:true`, `execution_enabled:false` and a reason: its remote triggers and private CI cost permission remain unverified. Register the complete approved set initially; registered identities cannot be changed or broadened through normal commands. Adding projects beyond these two requires a separately reviewed design/approval.

## Task specification and commands

Create a local JSON file containing exactly these fields:

```json
{
  "task_id": "controller-example",
  "project": "voca",
  "repo_name": "MohammedA47/Voca",
  "repo_id": 1219099434,
  "issue_number": 3,
  "base_sha": "<fresh full lowercase main SHA>",
  "branch": "automation/voca-example",
  "checkout": "/absolute/task-writer-checkout",
  "review_path": "/absolute/task-review-root",
  "scope_prefixes": ["tools/voca_controller", "tests/controller", "docs/controller.md"],
  "spec_text": "The approved task and design, with concrete boundaries",
  "acceptance_text": "The independently verifiable acceptance criteria",
  "complexity": "complex",
  "purpose": "controller",
  "routing_reason": "State/process correctness needs deeper reasoning",
  "decisions_approved": true,
  "claude_authorized": false,
  "same_provider_review_approved": true,
  "ci_workflow": ".github/workflows/controller.yml",
  "ci_job": "controller-tests"
}
```

Resolve and prepare the clean task branch in its own checkout before approval. The controller verifies exact origin, branch, repository ID/public status and fresh remote main SHA before agent execution. Arena cannot run even if issue text requests it. Each task has distinct writer/review paths, namespaced logs and repository-bound evidence. Reused task IDs cannot move between projects or workspaces. An identical specification is idempotent; changed specifications remove execution/review/CI approval without resetting budgets. Changes to base/checkout require explicit operator reconciliation; the controller never resets, cleans or discards work automatically.

```sh
python3 -m voca_controller --state-dir /absolute/local-controller-state approve --spec /absolute/task.json
# Inspect canonical digest and routes, then repeat with --ack <digest> --execute.
python3 -m voca_controller --state-dir /absolute/local-controller-state authorize --task controller-example --ack <digest> --execute
python3 -m voca_controller --state-dir /absolute/local-controller-state run --task controller-example --role writer --execute
python3 -m voca_controller --state-dir /absolute/local-controller-state run --task controller-example --role reviewer --execute
```

The writer receives the persisted approved specification, acceptance criteria, prior findings and a bounded complete snapshot of scoped text files. It runs tool-disabled/read-only and returns a JSON patch proposal. The controller rejects binary/rename/symlink/out-of-scope proposals, verifies both staged and unstaged cleanliness, checks the patch against the index, applies it, then makes a local commit with hooks/signing disabled. It cannot choose a new project/command/provider from issue text. Review uses a separate detached worktree at that SHA, a fresh agent process, and the complete bounded diff. Binary/oversized changes stop for manual review. Changed HEAD, dirty content, remote base, missing approvals, auth/quota/permission errors or uncertain children stop the task. No review prefix such as “LGTM” can substitute for the structured exact-SHA result. A reviewer pass leaves the task awaiting CI.

Supervise publication outside the controller. After inspecting the existing Voca-only safe trigger path and publishing a task branch/draft PR, record the actual CI run:

```sh
python3 -m voca_controller --state-dir /absolute/local-controller-state observe-ci --task controller-example --run-id <actual-run-id> --execute
```

This reads the public GitHub API without credentials and checks repository, source repository, branch, SHA, workflow path, event, completed success and the expected job. It ends at `awaiting-human-release`; that is evidence preparation, not permission to merge or deploy. Voca's production approval policy remains procedural until a separately approved technical gate is configured. GitHub environment gates do not control Xcode Cloud or App Store actions.

## Models, effort and quota

| Profile | Model | Effort |
|---|---|---|
| claude-routine | claude-sonnet-4-6 | low |
| claude-deep | claude-opus-4-6 | high |
| codex-routine | gpt-6.1-sol | low |
| codex-deep | gpt-6-astra | high |

These exact client selections were observed in the earlier supervised session; they are not a guarantee of continuing entitlement/quota. Claude uses `--model` and `--effort`; Codex uses `--model` and `-c model_reasoning_effort=...`. Unsupported profiles are rejected; failures never fall back to another provider/API key. The existing CLI must report subscription authentication. The controller never extracts stored credentials. It rejects provider/API environment overrides.

For **product** work, routine tasks select Codex/low writer and Claude/low reviewer; complex tasks select Claude/high writer and Codex/high reviewer. Product execution requires task-specific `claude_authorized:true` acknowledgement and approved decisions. The lead should reserve the limited Claude subscription for substantive product work and include only necessary context.

For **controller setup only**, the explicitly approved exception selects Codex for both roles in separate processes/checkouts; the reviewer uses the deep profile. `claude_authorized` must be false and `same_provider_review_approved` true. Same-provider review is recorded honestly. There is no Claude probe command and no automatic capability/model discovery call.

`route --spec <file>` shows the selected profiles without invocation. `escalate --task <id> --role writer|reviewer --reason <reason> --execute` allows one routine-to-deep escalation per role, preserving correction/infra budgets. Every task/run/review records requested model, effort, catalog version and rationale. Claude-reported model mismatches fail; Codex's JSONL does not report a resolved model ID, so evidence distinguishes requested selection from provider-attested identity.

The default per-invocation timeout is 180 seconds; the operator can choose 1–600 with `--timeout`. Output is checked against a 1 MB limit while running (a polling interval can overshoot); complete review inputs are capped at 180 KB. No automatic retry loop or automatic model escalation runs. All subsequent writer launches conservatively consume the durable three-correction budget, including failed launches. Infrastructure errors independently allow at most two further attempts per task/role; auth/quota/permission errors pause immediately. Reapproval/escalation/restart do not reset these counts.

## Recovery and external-operation ledger

Real agent invocations use the existing macOS `sandbox-exec` with a process-local `deny process-fork` profile. This prevents a detached descendant from escaping process-group accounting; it changes no persistent system setting. Unsupported platforms fail closed before spawning an agent. A client that needs to fork a helper (including an authentication helper) will fail and require supervised investigation; no broader permission fallback is automatic. One bounded, tool-disabled Codex smoke request under this confinement returned the expected marker using the existing ChatGPT login (requested gpt-6.1-sol/low). The bundled native executable is used because its shell wrapper needs a forbidden fork. This verifies that adapter path, not a full live implementation/review lifecycle. Claude has not been invoked under the new confinement; its integration remains unverified to preserve the user’s allowance.

A durable uncertain launch is written before creating a child. The SQLite fence and host lock prevent a second writer. Timeout cleanup targets only the known process group, verifies identity, and checks that no live descendants remain. If the spawn window has no recorded PID/group, recovery cannot prove completion and stays blocked. It does not kill unknown/reused processes or silently retry.

`reconcile --execute` observes known groups. Live/unknown groups remain blocked. Known-ended operations become `awaiting-human`, never automatically resumed. Preserve files, investigate the failed run, then approve a reconciled specification only after restoring a valid clean task checkpoint; do not erase the database to bypass exhausted budgets. An unvalidated legacy database is rejected for manual migration, not silently recreated.

`external --task <id> --key <unique-id> --action plan|uncertain|observed-absent|observed-succeeded --payload <json-file>` prepares a digest of task/key/payload. Repeat with `--ack <digest> --execute` to record a supervised operation. Same-key/different-payload reuse fails. Unknown outcomes must be explicitly observed before retry; a successful final operation cannot be restarted. Observations are labeled **operator-attested**, distinct from API-observed CI. No command actually performs the external push/PR operation.

## Verification and limitations

```sh
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=tools python3 -m unittest discover -s tests/controller -v
```

Tests use fake adapters and mocked GitHub responses plus real disposable local git repositories/processes. They cover the wired lifecycle, budgets/restart, approvals, stale evidence, uncertain spawn, timeout handling, forbidden detached processes on macOS, unsupported-platform refusal on Linux, process contention, staged-index scope bypasses, project contamination and model-routing policy. They do not invoke Claude/Codex, contact product backends, or prove live private-repository integration. The public Voca workflow runs the suite on a standard Ubuntu runner with read-only permissions and no secrets, installation, cache, artifact upload or deployment. Arena CI is not enabled.

Keep raw prompts/provider diagnostics private: local logs can contain task source and private project context. Do not attach the private project registry or whole state directory to Voca's public PR. The controller does not enforce a production security boundary against the repository owner or protect credentials from every same-user process. Human decisions, protected publishing identities and background hosting remain separately governed.
