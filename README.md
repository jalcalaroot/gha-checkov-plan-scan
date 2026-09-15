# gha-checkov-plan-scan

A composite GitHub Action that scans a Terraform plan (JSON) with [Checkov](https://github.com/bridgecrewio/checkov), enriched against the real HCL source. Shared across every repo in this account that runs Terraform, so this check is written once instead of copy-pasted per repo.

## Why this exists

The static HCL scan Checkov already runs in every repo here can't see resolved values — a `data` source, a variable with no default, a module output. Scanning the actual `terraform plan` (which Terraform already resolved during `plan`) catches what a purely static scan can miss. This is a **second, complementary** pass, not a replacement for the existing `directory: .` Checkov step.

## ⚠️ Known limitation: skip comments are not reliably respected in plan-scan mode

Verified by hand before writing this action: an HCL scan (`checkov -d .`) respects `#checkov:skip=...` comments correctly. The **same** comments, on the **same** resources, are ignored by a plan-file scan (`checkov -f plan.json`) — even with `--repo-root-for-plan-enrichment` and `--deep-analysis` both set. This isn't a config mistake; it's a known, currently-open upstream limitation ([bridgecrewio/checkov#2047](https://github.com/bridgecrewio/checkov/issues/2047), [#5212](https://github.com/bridgecrewio/checkov/issues/5212), [#1286](https://github.com/bridgecrewio/checkov/issues/1286), [#7126](https://github.com/bridgecrewio/checkov/issues/7126)).

Practical effect: this action **defaults to `soft-fail: true`**. Every already-accepted, already-documented exception in a repo's HCL scan will show up again here as a "new" finding, because the skip never reached the plan scan. Making this blocking by default would break CI on rollout for that reason alone, not because anything is actually wrong. Flip `soft-fail` to `false` for a given repo only after manually confirming its plan-scan findings aren't just duplicating accepted skips.

## Usage

Inside an existing `terraform plan` job, right after producing the plan JSON (the same file used for [`gha-iam-policy-autopilot`](https://github.com/jalcalaroot/gha-iam-policy-autopilot) if that's already wired in — no need to generate it twice):

```yaml
- name: Terraform plan
  run: terraform plan -input=false -out=tfplan

- name: Terraform plan (JSON)
  run: terraform show -json tfplan > plan.json

- name: Checkov Plan Scan
  uses: jalcalaroot/gha-checkov-plan-scan@<pinned-sha>
  with:
    plan-file: plan.json
    repo-root: . # directory containing the HCL that produced the plan
```

The SARIF report is written locally (`checkov-plan-results.sarif` by default) — upload it to the Security tab yourself if wanted, same as the existing HCL Checkov step does, since this action doesn't assume any particular repo's permissions for that.

### Custom checks that need a resolved plan

Some custom checks (e.g. [`johan-cloud-policies`](https://github.com/jalcalaroot/johan-cloud-policies)'s `custom_policies/plan_only/`) are specifically written to read a resource attribute that only resolves to its real value against a plan, never against static HCL — pass their directory via `external-checks-dir`:

```yaml
- name: Checkout custom policies
  uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  with:
    repository: jalcalaroot/johan-cloud-policies
    path: .johan-cloud-policies
    ref: <pinned-sha>

- name: Checkov Plan Scan
  uses: jalcalaroot/gha-checkov-plan-scan@<pinned-sha>
  with:
    plan-file: plan.json
    repo-root: .
    external-checks-dir: .johan-cloud-policies/custom_policies/plan_only/aws # or plan_only/azure
```

A check written for static HCL scanning also still works here (if it doesn't touch a cross-resource-referenced attribute) — this is additive, not a separate check registry.

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `plan-file` | yes | — | Path to the Terraform plan in JSON format (`terraform show -json <planfile>`) |
| `repo-root` | no | `.` | Directory containing the HCL source that produced the plan |
| `checkov-version` | no | `3.3.17` | Pinned checkov version to install |
| `soft-fail` | no | `true` | See the limitation above before setting this to `false` |
| `sarif-file` | no | `checkov-plan-results.sarif` | Output filename for the SARIF report |
| `external-checks-dir` | no | `""` (disabled) | Path to a directory of custom checks meant to run against the resolved plan |

## Outputs

| Output | Description |
|---|---|
| `sarif-file` | Path to the generated SARIF report |
| `exitcode` | Exit code checkov returned (0 = no findings; meaningless when `soft-fail` is true, since checkov itself always exits 0 in that mode) |

## Design notes

- **No AWS/Azure credentials needed.** Same as the plan generation step it runs after — this only ever reads a JSON file already on disk.
- Installs checkov via `pip`, pinned by exact version — no Docker image, keeps the action simple.
- Consuming repos should pin this action by commit SHA, same convention as every other action reference in this account's workflows — never a floating tag.

## Architecture: this repo doesn't run anything itself

This is **not** a central service that other repos call out to at runtime. It's just where the composite action's code (`action.yml`) lives. When a consuming repo references it (`uses: jalcalaroot/gha-checkov-plan-scan@<sha>`), GitHub Actions checks that code out and runs it **inside the consuming repo's own job** — its own runner, its own permissions, its own filesystem. There's one copy of the logic, but N independent executions, one per repo's own pipeline. Same model as [`gha-iam-policy-autopilot`](https://github.com/jalcalaroot/gha-iam-policy-autopilot).

Net effect on a consuming repo's `terraform-plan.yml`: it goes from one Checkov pass to two —

1. **Existing, unchanged**: `bridgecrewio/checkov-action` against `directory: .` (the static HCL) — blocking.
2. **This action**: against the resolved `terraform plan` — non-blocking (see the limitation above).

Nothing about Checkov's own ruleset or config changed. What changed is the *input* it gets to look at a second time — resolved values a static HCL scan structurally cannot see.

## Test

`.github/workflows/test.yml` runs this action three times against a fixture in `test/` (an `aws_s3_bucket` with several checks deliberately left un-skipped so there's something real to find, plus an `aws_iam_role`, fake credentials, `skip_credentials_validation = true` — no real AWS account involved): once with the default `soft-fail: true` (must succeed despite real findings), once with `soft-fail: false` (must fail), and once with `external-checks-dir` pointed at a test-only check (`test/custom_checks/`) that always fails — asserting its ID shows up in the SARIF report only when that input is actually set, proving the flag reaches the underlying checkov invocation rather than just existing as an unused input.
