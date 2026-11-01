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

A `push` trigger on `main` is not configured in this workflow; CI currently runs
on `automation/voca-ci-foundation` pushes and PRs targeting `main`. Adding a `main`
push trigger is a future decision. Direct pushes to `main` are technically possible
(no branch protection is configured); the procedural policy requires human approval
for all merges and releases regardless.

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
   (requires modern xcresulttool (Xcode 26+); see PR for tested versions) and validates
   `totalTestCount > 0`, `passedTests > 0`, `passedTests == totalTestCount`,
   `failedTests == 0`, `skippedTests == 0`, and `result == "Passed"`. Any deviation
   exits non-zero. Runs even when prior steps fail (`if: always()`).

---

## xcresult Artifacts

The `TestResults.xcresult` bundle is written to the working directory on the
runner during each CI run. **Artifact upload is not configured**; the bundle is
only accessible on the runner while it is alive (within the same job via steps).

To inspect test results locally, open the `TestResults.xcresult` file produced by
a local run in Xcode Organizer or with `xcrun xcresulttool`.

---

## Running Locally

Use a single consistent `derivedData` path so the App build artefacts used by the
resource verification step are the same ones produced by the build step. Avoid
pointing `derivedData` at tracked source directories.

**Important — stale result bundle:** `xcodebuild test` will fail if
`-resultBundlePath` points to an existing `.xcresult` directory from a prior run.
The steps below use `mktemp -u` to generate a unique path on each invocation,
so no prior bundle is ever overwritten.

### Step 1 — Build App (unsigned, simulator)

```sh
xcodebuild build \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -derivedDataPath /tmp/voca-build \
  CODE_SIGNING_ALLOWED=NO
```

### Step 2 — Verify oxford_vocabulary.json in built bundle

```sh
APP="/tmp/voca-build/Build/Products/Debug-iphonesimulator/App.app"
cmp "$APP/oxford_vocabulary.json" ios/App/App/Services/oxford_vocabulary.json \
  && echo "Resource OK: $(wc -c < "$APP/oxford_vocabulary.json" | tr -d ' ') bytes" \
  || { echo "Resource mismatch or missing"; exit 1; }
```

### Step 3 — Run tests

Use a unique result path to avoid conflicts with prior runs (xcodebuild refuses to
overwrite an existing `.xcresult`):

```sh
RESULT_PATH=$(mktemp -u /tmp/voca-TestResults-XXXXXX).xcresult

xcodebuild test \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -derivedDataPath /tmp/voca-build \
  -only-testing:AppTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath "$RESULT_PATH"
```

**Note:** `name=iPhone 17,OS=26.5` matches the CI runner exactly. Locally, use
`OS=latest` or whichever simulator is available:

```sh
xcrun simctl list devices available | grep -i iphone
```

### Inspect Results Locally

```sh
# View summary (requires modern xcresulttool (Xcode 26+); see PR for tested versions):
xcrun xcresulttool get test-results summary \
  --path "$RESULT_PATH" --compact

# Open in Xcode Organizer:
open "$RESULT_PATH"
```

### Local Negative Rehearsal (reviewer use)

To confirm the empty-dataset gate fires, alter only the built test bundle copy
(never source), run tests without rebuilding, and let a `trap` guarantee restoration
regardless of outcome. The entire sequence runs in a subshell so the trap fires on
any error or normal exit:

```sh
(
  set -euo pipefail

  # Deterministic path produced by the build steps above.
  BUNDLE="/tmp/voca-build/Build/Products/Debug-iphonesimulator/AppTests.xctest"

  # Back up the bundled JSON; restore it unconditionally on EXIT.
  BAK=$(mktemp /tmp/oxford_vocabulary.json.XXXXXX)
  trap 'cp "$BAK" "$BUNDLE/oxford_vocabulary.json"; rm -f "$BAK"' EXIT

  cp "$BUNDLE/oxford_vocabulary.json" "$BAK"
  echo '[]' > "$BUNDLE/oxford_vocabulary.json"

  # Unique result path — no prior bundle to conflict with.
  RESULT_PATH=$(mktemp -u /tmp/voca-negative-XXXXXX).xcresult

  # Run without rebuilding; capture exit without letting set -e abort early.
  test_exit=0
  xcodebuild test-without-building \
    -workspace ios/App/App.xcworkspace \
    -scheme App \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
    -derivedDataPath /tmp/voca-build \
    -only-testing:AppTests \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "$RESULT_PATH" \
    || test_exit=$?

  # The run must fail; success would indicate the gate is broken.
  if [[ "$test_exit" -eq 0 ]]; then
    echo "ERROR: xcodebuild unexpectedly succeeded — gate may be broken" >&2
    exit 1
  fi
  echo "xcodebuild exited $test_exit (expected non-zero for failing tests)"

  # Inspect the result; setUpWithError XCTFail+throw and all five
  # WordBundledJSONTests methods should appear as failures, not skips.
  xcrun xcresulttool get test-results summary \
    --path "$RESULT_PATH" --compact
)
```

Alternatively, reviewer evidence may be included in the PR review comment rather
than modifying any source.

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
| Backend / Auth services | **Not covered** |

The test count reported by CI reflects `WordDecodingTests` + `WordBundledJSONTests`
test methods; the exact number is reported in the job summary on each run.

---

## Xcode Cloud

Xcode Cloud is a separate pipeline that archives the `App` scheme. Its workflow is
not modified by this issue. The shared `App.xcscheme` added here does not change
archive behaviour: the scheme's `ArchiveAction` still builds `Release` for the `App`
target only, and AppTests is not in the archive build entries
(`buildForArchiving = NO`).

The observed enabled Xcode Cloud configuration: Default workflow, triggers on `main`
branch changes, action Archive / App, Distribution Preparation None, no post-actions;
unchanged by this issue. No automation triggers a release or App Store submission
without explicit human action.

---

## Roles and Gates (see also AGENTS.md)

- **Claude (automation/voca-ci-foundation)**: sole implementation writer for this
  issue; exclusive writer role ends when this invocation finishes.
- **Codex**: independent reviewer; verifies the exact commit SHA, runs tests
  locally, and may request up to 3 corrections before escalating to human review.
- **Human**: required for merging the PR to `main` and for any production
  deployment. GitHub branch protections on `main` are not currently configured
  in the repository; the process gate is procedural, not technically enforced.
- **Xcode Cloud archive** may be triggered by pushes to `main`; all production
  releases and App Store submissions require explicit human approval regardless.

No automation merges this PR or publishes a release.
