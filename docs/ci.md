# Voca iOS CI

## Overview

This document describes the GitHub Actions CI pipeline for Voca's iOS unit tests
and the AppTests XCTest bundle introduced in issue #1.

---

## Trigger Conditions

| Event | Branches |
| --- | --- |
| `push` | `automation/voca-ci-foundation` |
| `pull_request` | base `main` |

No `push` trigger on `main` is configured yet; that is reserved for a future
decision after the CI pipeline has been validated.

### Repository Guard

The job is gated at the job level:

```yaml
if: github.repository == 'MohammedA47/Voca' && github.event.repository.private == false
```

This prevents the job from allocating a runner on forks or private copies of the
repository where the pipeline has not been authorized.

### Concurrency

One run per `workflow + ref`; stale runs are cancelled when a newer commit
arrives on the same branch or PR.

---

## Runner Environment

| Setting | Value |
| --- | --- |
| `runs-on` | `macos-26` |
| `DEVELOPER_DIR` | `/Applications/Xcode_26.5.app/Contents/Developer` |
| Timeout | 20 minutes |
| Destination | `platform=iOS Simulator,name=iPhone 17,OS=26.5` |

The destination uses `name=iPhone 17` because that is the verified device name in
the official `macos-26` runner inventory. If a run fails with "Unable to find a
destination matching the provided destination specifier", check the
`Log toolchain and available simulators` step for the actual device names
(`xcrun simctl list devices available`).

No packages, caches, artifact uploads, or extra `setup-xcode` steps are used.
The runner already has Xcode 26.5 at the declared `DEVELOPER_DIR` path.

---

## Pipeline Steps

1. **Checkout** — `actions/checkout` pinned to SHA
   `11d5960a326750d5838078e36cf38b85af677262` (v4), `persist-credentials: false`.

2. **Log toolchain** — Prints Xcode version and lists iPhone 17 simulators.

3. **Build App** — Builds the `App` target for the simulator using `Debug`
   configuration and `CODE_SIGNING_ALLOWED=NO`. Output is written to `.build/`.

4. **Verify resource** — Checks that `oxford_vocabulary.json` is present in the
   built `App.app` bundle and is byte-for-byte identical to the source file at
   `ios/App/App/Services/oxford_vocabulary.json`. A stale or missing copy fails
   the pipeline before tests run.

5. **Run tests** — Runs the `AppTests` target via `-only-testing:AppTests` with
   `-parallel-testing-enabled NO` for deterministic single-simulator execution.
   No app host: `TEST_HOST` and `BUNDLE_LOADER` are intentionally absent from
   the test target's build settings. The App binary is never launched.

6. **Report results** — Reads `TestResults.xcresult` using
   `xcrun xcresulttool get test-results summary --path TestResults.xcresult --compact`
   (Xcode 26 syntax) and validates `totalTestCount > 0`, `passedTests > 0`,
   `failedTests == 0`, and `result == "Passed"`. Any deviation exits non-zero.
   Runs even when prior steps fail (`if: always()`).

---

## xcresult Artifacts

The `TestResults.xcresult` bundle is written to the working directory on the
runner during each CI run. **Artifact upload is not configured**; the bundle is
only accessible on the runner while it is alive (within the same job via steps).

To inspect test results locally, open the `TestResults.xcresult` file produced by
a local run in Xcode Organizer or with `xcrun xcresulttool`.

---

## Running Locally

### Build + Test (default Xcode)

```sh
xcodebuild test \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:AppTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath TestResults.xcresult
```

**Note:** The `name=iPhone 17,OS=26.5` destination matches the CI runner.
Locally you can substitute any available simulator:

```sh
# List available simulators:
xcrun simctl list devices available | grep -i iphone

# Example with a different simulator:
-destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'
```

### Inspect Results Locally

```sh
# View summary (Xcode 15+ syntax):
xcrun xcresulttool get test-results summary \
  --path TestResults.xcresult --compact

# Open in Xcode Organizer:
open TestResults.xcresult
```

---

## AppTests Scope

`AppTests` is a **non-hosted** XCTest unit-test bundle (`bundle.unit-test`)
that tests the `Word` model in isolation.

| Scope | Covered |
| --- | --- |
| `Word` struct JSON decoding (minimal/full values) | Yes |
| `Phonetics` optional field combinations | Yes |
| Null / absent / empty optional fields | Yes |
| Missing required fields throw `DecodingError` | Yes |
| `oxford_vocabulary.json` bundle presence | Yes (setUpWithError throws on absence) |
| Dataset non-empty, unique IDs, trimmed strings | Yes |
| All CEFR levels valid (`A1`–`C2`) | Yes |
| UI flows, authentication, networking | **Not covered** |
| `VocabularyService` (`@Observable @MainActor`) | **Not covered** — excluded by design |
| Backend / RevenueCat / Auth services | **Not covered** |

The test count reported by CI reflects `WordDecodingTests` + `WordBundledJSONTests`
test methods; the exact number is reported in the job summary on each run.

---

## Xcode Cloud

Xcode Cloud is a separate pipeline that archives the `App` scheme on `main`.
Its workflow is not modified by this issue. The shared `App.xcscheme` added here
does not change archive behaviour: the scheme's `ArchiveAction` still builds
`Release` for the `App` target only, and AppTests is not in the archive build
entries (`buildForArchiving = NO`).

---

## Roles and Gates (see also AGENTS.md)

- **Claude (automation/voca-ci-foundation)**: sole implementation writer for this
  issue; exclusive writer role ends when this invocation finishes.
- **Codex**: independent reviewer; verifies the exact commit SHA, runs tests
  locally, and may request up to 3 corrections before escalating to human review.
- **Human**: required for merging the PR to `main` and for any production
  deployment. GitHub branch protections on `main` are not currently configured
  in the repository; the process gate is procedural, not technically enforced.
- **Xcode Cloud archive** on `main` is triggered only after human merge approval.

No automation can merge this PR or publish a release.
