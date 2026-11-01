# AGENTS.md — Voca Automation Scope

This file documents the roles, constraints, and process gates for automated agents
contributing to this repository.

---

## Scope

Agents operate within the Voca iOS app repository (`ios/` Swift sources, test
infrastructure, `.github/workflows/`, and `docs/`). Agents must not modify other
repositories, production signing credentials, entitlements, Xcode Cloud workflows,
or App Store configuration.

---

## Roles

| Role | Description |
| --- | --- |
| **Dollman (Lead)** | Coordinates GitHub issues, creates feature branches, opens and updates draft PRs, and monitors CI using existing repository credentials. May commit and push dedicated task branches within Voca scope after implementation validation. Does not merge to `main` or trigger releases without human approval. |
| **Claude (Primary Developer / Designer)** | Primary implementation writer and designer for assigned issues. May build and test locally within the accepted task scope. Also independently reviews Codex-authored changes before they are accepted into the branch. |
| **Codex (Reviewer / Secondary Developer)** | Independent reviewer and tester; verifies implementation against the accepted plan using a separate checkout and makes no implementation edits during review. May be assigned small secondary development tasks with its own writer invocation; such changes are independently reviewed by Claude. |
| **Human Maintainer** | Required for merging PRs to `main`, triggering releases, and any decisions affecting production users or spending. |

---

## Exclusive Writer Ownership

Each accepted plan names one implementation writer and the exact files in scope.
No other agent may edit those files during an active invocation. The assigned writer
may build and test locally as part of the task. Reviewer agents use a separate
checkout and make no implementation edits. Exclusive writer ownership ends when the
implementation invocation finishes; subsequent corrections or follow-up work require
a new explicit assignment.

---

## Correction Attempts

The reviewer may request corrections for issues found during review. A maximum of
**3 correction attempts** are allowed before escalating to human review. Corrections
must stay within the originally scoped files and plan intent. Each correction
invalidates the previous reviewed SHA; the reviewer re-runs tests against the exact
new commit SHA.

---

## Human Approval Gates

The following require explicit human approval and cannot be automated:

- Merging a pull request to `main`
- Triggering or approving an Xcode Cloud archive or App Store submission
- Modifying signing certificates, provisioning profiles, or entitlements
- Changing production backend configuration or API credentials
- Publishing or updating the app on the App Store
- Major product or architecture decisions
- Destructive database operations
- Sensitive security or permission changes
- Engaging paid services or incurring spending
- Actions affecting other projects or repositories

> Note: GitHub branch protections on `main` are not currently configured in this
> repository. The gates above are procedural commitments, not technically enforced
> barriers. This file does not claim enforcement exists.

---

## Agent Constraints

Agents must not:

- Read, write, or disclose `.env` files, secrets, or credential files
- Install software or modify system configuration outside the task scope
- Make unapproved calls to production APIs, backend services, or paid external services
- Automatically install new credentials or security configurations
- Modify Xcode Cloud workflow configuration
- Change app bundle ID, signing team, or entitlements
- Edit files outside their assigned scope for the current task

Ordinary GitHub coordination (issues, branches, draft PRs, CI status) by the lead
agent using existing repository credentials is permitted. Dependency documentation
references are permitted. What is prohibited is unapproved production/backend/paid
service calls and any disclosure of secrets.
