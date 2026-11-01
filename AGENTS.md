# AGENTS.md — Voca Automation Scope

This file documents the roles, constraints, and process gates that apply when
automated agents contribute to this repository.

---

## Scope

Automated agents operate exclusively within the **Voca iOS app repository**
(`ios/` Swift sources, test infrastructure, `.github/workflows/`, and `docs/`).
Agents must not modify other repositories, production signing credentials,
entitlements, Xcode Cloud workflows, or App Store configuration.

---

## Roles

| Role | Description |
| --- | --- |
| **Implementation writer** | The agent assigned to a specific issue branch. Sole writer for the files listed in the accepted plan for that issue. Writes, edits, and creates files only; does not run builds, push commits, or interact with external services. |
| **Reviewer (Codex)** | An independent agent that verifies the implementation against the plan, runs tests locally, checks for correctness, and may request corrections. The reviewer does not modify source files. |
| **Human maintainer** | Required for merging PRs to `main`, triggering releases, and any decisions that affect production users. |

---

## Exclusive Writer Ownership

Each accepted plan names the implementation writer and the exact files in scope.
No other agent or automation may edit those files during the same invocation.
Exclusive writer ownership ends when the implementation invocation finishes;
subsequent corrections or follow-up work require a new explicit assignment.

---

## Correction Attempts

The reviewer may request corrections for issues found during review. A maximum of
**3 correction attempts** are allowed before the issue is escalated to human
review. Corrections must stay within the originally scoped files and plan intent.

---

## Human Release Gates

The following actions **require explicit human approval** and cannot be automated:

- Merging a pull request to `main`
- Triggering or approving an Xcode Cloud archive / App Store submission
- Modifying signing certificates, provisioning profiles, or entitlements
- Changing production backend configuration or API credentials
- Publishing or updating the app on the App Store

> Note: GitHub branch protections on `main` are not currently configured in this
> repository. The release gates above are procedural commitments, not technically
> enforced barriers. This file does not claim that enforcement exists.

---

## What Agents Must Not Do

- Commit or push code
- Read or modify `.env`, secrets, or credential files
- Install software or modify system configuration
- Access external networks, APIs, or backend services
- Modify Xcode Cloud workflow configuration
- Change app bundle ID, signing team, or entitlements
- Edit files outside their assigned scope
