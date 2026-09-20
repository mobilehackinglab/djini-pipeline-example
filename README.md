# djini-pipeline-example

A ready-to-run example repository showing how to run a **djini** mobile security
scan inside a GitHub Actions pipeline: build the app → upload to djini → wait for
the scan → surface findings in the PR (GitHub Code Scanning) → attach the report →
**fail the build when findings exceed a threshold**.

This repo is **runnable as-is**: it bundles a real Android lab app under
[`sample-app/`](sample-app/), and the workflow builds it with Gradle and scans the
resulting APK — a complete build → scan → gate pipeline you can watch end-to-end.
To adopt it for your own project, swap the build step for your app's build (the
only contract is that it hands the scan a single `.apk` / `.aab` / `.ipa`).

It uses the same public API as the `example.sh` script you can download from your
djini **Settings → Pipeline integration** page — just wired for CI, with a
severity gate, SARIF upload, build artifacts, and a GitHub job summary.

```
.
├── .github/
│   ├── workflows/djini-security-scan.yml   # the workflow
│   └── scripts/djini-scan.sh               # the scan runner (curl + jq)
├── sample-app/                             # bundled Android lab (Gradle) it builds & scans
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
That's it — push (or hit **Run workflow**), and it builds `sample-app/` and scans
it on every PR and on `main`.

**To scan your own app instead:** replace the `Build APK` step in
[`.github/workflows/djini-security-scan.yml`](.github/workflows/djini-security-scan.yml)
with your build, so `steps.build.outputs.artifact` points at your built file, and
delete `sample-app/` if you don't need it. An iOS note is in the workflow comments.

> **Adding this to an existing repo instead of using this template?** Copy
> `.github/workflows/djini-security-scan.yml` and `.github/scripts/djini-scan.sh`
> into the same paths in your repo, then do steps 1–3 above.

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
