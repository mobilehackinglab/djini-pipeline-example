# djini-pipeline-example

A ready-to-run example repository showing how to run a **djini** mobile security
scan inside a GitHub Actions pipeline: build the app → upload to djini → wait for
the scan → surface findings in the PR (GitHub Code Scanning) → attach the report →
**fail the build when findings exceed a threshold**.

This repo is **runnable as-is** and ships **two pipelines**, each with a bundled
lab app:

| Pipeline | Workflow | Lab app | Binary |
|----------|----------|---------|--------|
| **Android** | `djini-android.yml` | [`sample-app-android/`](sample-app-android/) (Gradle) | prebuilt APK by default¹ |
| **iOS** | `djini-ios.yml` | [`sample-app-ios/`](sample-app-ios/) (Objective-C "Linkliar") | prebuilt IPA² |

Both are **manual** (run from the **Actions** tab → *Run workflow*) — uncomment the
`push`/`pull_request` triggers to gate PRs automatically. To adopt one for your own
project, point its build step at your app (the only contract is that it hands the
scan a single `.apk` / `.aab` / `.ipa`).

¹ To keep the demo fast, the Android workflow uses the committed prebuilt APK; a
commented-out Gradle block builds `sample-app-android/` from source instead.
² Building an `.ipa` in CI needs Apple signing secrets, which a demo shouldn't
require — so the iOS workflow uses the committed prebuilt IPA and scans the
Objective-C source. Swap in a `macos-latest` `xcodebuild` job to build for real
(see the workflow header).

It uses the same public API as the `example.sh` script you can download from your
djini **Settings → Pipeline integration** page — just wired for CI, with a
severity gate, SARIF upload, build artifacts, and a GitHub job summary.

```
.
├── .github/
│   ├── workflows/
│   │   ├── djini-android.yml    # Android pipeline
│   │   └── djini-ios.yml        # iOS pipeline
│   └── scripts/djini-scan.sh    # the scan runner (curl + jq), shared
├── sample-app-android/         # bundled Android lab (Gradle) + prebuilt APK
├── sample-app-ios/             # bundled iOS lab (Objective-C) + prebuilt IPA
└── README.md
```

## What it does

1. **Build** your app into a single artifact (`.apk` / `.aab` / `.ipa`).
2. **Upload** it to djini — `POST /api/dashboard/upload`.
3. **Start** the scan — `POST /api/dashboard/scans/<project>/process` (and, optionally, `.../deep-scan`).
4. **Poll** until it finishes — `GET /api/dashboard/scans/<project>/status`.
5. **Pull findings** — `GET /api/dashboard/scans/<project>/findings` (JSON severity counts).
6. **Download SARIF** — `GET /api/dashboard/scans/<project>/sarif` — and upload it to
   **GitHub Code Scanning** so findings show up as PR annotations and in the Security tab.
7. **Download** the PDF report and upload it (plus findings JSON + SARIF) as a build artifact.
8. **Gate** the build: exit non-zero when findings meet/exceed `--fail-on`.

Every request authenticates with a bearer **API key**, so nothing here needs your
console login.

## Setup (one-time)

1. **Create a djini API key** — djini → **Settings → API key**.
2. **Configure the repo** — *Settings → Secrets and variables → Actions*:
   | Name | Kind | Value |
   |------|------|-------|
   | `DJINI_API_KEY` | **Secret** | your djini API key (`sk-…`) |
   | `DJINI_BASE_URL` | **Variable** | your djini URL, e.g. `https://app.djini.ai` |

   The URL isn't sensitive, so it's a repo **variable** (stays readable in the run
   logs); only the API key is a secret. From the CLI:
   ```bash
   gh secret   set DJINI_API_KEY  --body 'sk-...'
   gh variable set DJINI_BASE_URL --body 'https://app.djini.ai'
   ```
That's it — go to the **Actions** tab, pick **djini security scan (Android)** or
**(iOS)**, and hit **Run workflow**.

**To scan your own app instead:** in the matching workflow
([`djini-android.yml`](.github/workflows/djini-android.yml) /
[`djini-ios.yml`](.github/workflows/djini-ios.yml)) replace the build step so
`steps.build.outputs.artifact` points at your built file, and delete the bundled
`sample-app-android/` / `sample-app-ios/` you don't need.

> **Adding this to an existing repo instead of using this template?** Copy the
> workflow you want and `.github/scripts/djini-scan.sh` into the same paths in
> your repo, then do steps 1–2 above.

## Quick source scan vs. full scan

The workflow has a `scan_type` picker (in **Run workflow**, or edit its default):

| `scan_type` | What runs | Speed | Best for |
|-------------|-----------|-------|----------|
| `quick-source` *(default)* | djini's **AI source scan** — a MASVS/MASWE swarm over your **source** (no decompile, no device) | fast | every PR / merge gate |
| `full` | the full binary scan (decompile + static + dynamic) of the built app | slow | release / nightly |

On `push`/`pull_request` (no inputs) the default `quick-source` applies. Under the
hood the script picks the mode from a single flag: `--source <dir>` runs the quick
source scan (it sends that tree to djini and triggers the source scan); omit it for
the full binary scan. `--deep-scan` only applies to `full`.

Both modes still build + upload the app so djini has the artifact; `quick-source`
additionally sends the source tree (`sample-app-android/`) and scans that instead of
decompiling.

### AI source scan needs your own model (BYOK)

The `quick-source` AI source scan is **BYOK-only** — it runs on **your own
OpenAI-compatible model**, not a djini-hosted one. If none is configured the scan
trigger returns `400 { "code": "byok_required" }` and the build fails with a clear
message. You have two options:

- **Prerequisite (once):** in djini → **Settings → BYOK → OpenAI Compatible**, add a
  base URL, API key and model. Nothing else to set in CI.
- **Configure from CI:** set these three (base URL + model as **Variables**, key as a
  **Secret**) and the script registers the model on the API key's account before each
  source scan:

  | Name | Kind | Example |
  |------|------|---------|
  | `DJINI_SOURCE_LLM_BASE_URL` | Variable | `https://openrouter.ai/api/v1` |
  | `DJINI_SOURCE_LLM_KEY` | Secret | `sk-or-…` |
  | `DJINI_SOURCE_LLM_MODEL` | Variable | `qwen/qwen3.8-flash` |

  On the CLI these map to `--source-llm-base-url` / `--source-llm-key` /
  `--source-llm-model` (or the `SOURCE_LLM_*` env vars). `full` scans don't need any
  of this.

## Tuning the gate

`--fail-on` decides what blocks a merge (a build fails if **any** finding at or
above that severity exists):

| `--fail-on` | Build fails when there is a finding of severity… |
|-------------|--------------------------------------------------|
| `critical`  | Critical |
| `high` *(default)* | Critical or High |
| `medium`    | Critical, High, or Medium |
| `low`       | any severity except Informational |
| `none`      | never fails — report-only mode |

Set it per-run from the **Run workflow** button (`workflow_dispatch`), or change
the default in the workflow. Add `--deep-scan` for a slower, deeper analysis.

## GitHub Code Scanning

The workflow uploads the merged SARIF via `github/codeql-action/upload-sarif`, so
djini findings appear inline on PRs and under **Security → Code scanning**. This
needs `security-events: write` permission (already set on the job) and works on
pushes and same-repo PRs. Uploads from **forked** PRs are blocked by GitHub — the
severity gate and the PDF/JSON artifacts still work there.

## Running the script by hand

The runner works outside CI too — useful for testing before you commit:

```bash
export API_KEY=sk-...                   # or pass --api-key
.github/scripts/djini-scan.sh \
  --file build/app-release.apk \
  --base-url https://app.djini.ai \
  --fail-on high
```

Run `.github/scripts/djini-scan.sh --help` for all flags. Requires `curl` and `jq`.

## Step outputs

The `Run djini scan` step exposes these outputs (usable in later steps, e.g. to
comment on a PR): `project`, `app_name`, `status`, `critical`, `high`, `medium`,
`low`, `informational`, `total`, `report`, `sarif`.

## Notes

- **iOS**: build/export the `.ipa` on a `macos-latest` job, upload it as an
  artifact, then download it in an `ubuntu-latest` job that runs the scan (the
  scan step itself only needs `curl` + `jq`).
- **Self-hosted djini with a private CA**: add `--skip-tls-verify` to the script
  invocation (do **not** use this against a public instance).
- **Scan duration**: standard scans usually finish in minutes; deep scans take
  longer. Tune `--interval` (poll cadence) and `--timeout` (give-up limit) to fit.
