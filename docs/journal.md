# Journal

Running notes on decisions, open questions and follow-ups for this pipeline.

## Decisions

### Check the PR title, not every commit message

_Decided 2026-09-28, BIOINFO-231._

**Decision:** CI checks that each PR's title follows `<type>: <TICKET-123> <description>` (e.g. `fix: BIOINFO-231 pin actions/checkout`), using `.github/workflows/ci-pr-title-lint.yml`. Individual commits on a branch are not checked. PRs are squash-merged.

**Why:**

- The lab guideline says PRs are "typically" squash-merged, and that the branch is rebased if someone else merged first.
- quality-control-pipeline and cnv-post-processing check commits with Ferlab's own action, `Ferlab-Ste-Justine/action-commit-lint`. Its README says it "will scan all the commits up to the last merge", stopping at the first commit starting with `Merge pull request #`, the message GitHub gives merge commits. It assumes PRs are merged with merge commits, which conflicts with the guideline.
- Under squash merging, that stopping point never appears. Here the action would have checked every commit back to #105, including squash titles like `Fix/bioinfo 228 update linting (#112)`, and failed on every push from now on.
- Even with merge commits, one badly worded commit on a branch keeps every later push red until someone rewrites history (`git rebase -i`) and force-pushes. That's easy to trigger by accident: a typo or a missing ticket number, a commit made in GitHub's web editor (`Update README.md`), accepting review suggestions (`Apply suggestions from code review`), or merging `main` into the branch. With squash merging, that effort buys nothing, since those commits don't reach `main`.
- With squash merging, the PR title becomes the commit message on `main`, so it's the one message worth checking. A bad title is fixed by editing it on GitHub, and the check reruns on its own. No history rewriting is needed.

**Details:** same format as the Ferlab action, except that the type must come first (the Ferlab action accepts the pattern anywhere in the message) and GitHub's `Revert "..."` titles are allowed. The individual commits of a squashed PR remain visible on the PR's Commits tab, and can be fetched with `git fetch origin pull/<number>/head`.

**Follow-ups:**

- For single-commit PRs, GitHub's default squash message is the commit's own message, not the PR title. An admin should set Settings → General → Pull Requests → "Default commit message" for squash merging to "Pull request title" (or "Pull request title and commit details") so the checked title is what lands on `main`.
- quality-control-pipeline and cnv-post-processing still use the Ferlab action with merge commits. Moving them to squash plus this title check keeps the three pipelines consistent with each other and with the lab guideline.

### Keep `ci-full-run.yml` alongside the nf-test pipeline tests

_Decided 2026-09-28, BIOINFO-231. Applies to all three pipelines._

**Decision:** keep `ci-full-run.yml`, a plain `nextflow run . -profile test,docker` on Nextflow 24.10.5 and 25.10.4, on every pull request, push to `main` and `v*` tag, even though `nf-test.yml`'s pipeline tests (`tests/default.nf.test`) also run the pipeline end to end with `-profile test,docker`.

**Why:**

- On pull requests, nf-test only runs the tests affected by the PR (`--changed-since HEAD^`). It works that out by following `include` statements between `.nf` files, plus the `triggers` list in `nf-test.config`. A PR that only changes files outside both, such as `conf/modules.config` or `conf/slivar.config`, can skip the pipeline test entirely. When this was decided, `assets/slivar-functions.js` and `assets/schema_input.json` were outside both too; BIOINFO-233 added them to `triggers` (`assets/*.js` covers the slivar functions).
- That gap is real: the parental-origin bug (BIOINFO-217, fixed in #110) lived in `assets/slivar-functions.js`, and the full run in `ci.yml` (now `ci-full-run.yml`) is the job that caught it in CI.
- `ci-full-run.yml` always runs, whatever the PR changes, so it gives a signal that doesn't depend on change detection.

**Cost:** one extra full pipeline run per Nextflow version on every PR, partly overlapping the nf-test pipeline test. We accept that cost for a check that doesn't depend on change detection.

**Considered and set aside:**

- Dropping `ci-full-run.yml` and relying on nf-test alone, possibly after adding the `conf/` files to `triggers`. That leaves any file outside the `include` graph and outside `triggers` untested, and every new asset would have to be remembered in `triggers`.
- Using `ci-full-run.yml` to test another container engine instead. Production runs on Kubernetes, which can't reasonably be tested on GitHub's hosted runners.

## TODO

### Require `confirm-pass` before merging into `main`

_Noted 2026-09-28, while working on BIOINFO-231._

**Current state:** `main` is protected, but its list of required status checks is empty, so a PR can be merged even when CI fails. PR #107 was merged that way.

**Proposal:** in the `main` branch protection rule, require these checks:

- `confirm-pass` from `.github/workflows/nf-test.yml`. It summarizes the whole nf-test matrix: it fails if any shard or Nextflow version fails, and ignores the non-blocking `latest-everything` leg. Because it's a single check, it keeps working when `max_shards` or the tested Nextflow versions change. Requiring each `docker | <version> | <shard>` job instead would break whenever those change.
- `pre-commit` and `nf-core` from `.github/workflows/linting.yml`.

Once required, a failing check blocks every merge method (squash and merge, merge commit, rebase).

**Before enabling it:**

1. Remove `paths-ignore` from `nf-test.yml`. A required check that never runs blocks the PR indefinitely ("Waiting for status to be reported"). For docs-only PRs the workflow currently doesn't start at all, so `confirm-pass` would never report. Without `paths-ignore`, `nf-test-changes` finds no affected tests, the test jobs are skipped, and `confirm-pass` still runs and passes. Only a short dry-run job is added to docs-only PRs.
2. Change `confirm-pass` in `nf-test.yml` from `needs: [nf-test]` to `needs: [nf-test-changes, nf-test]`. As it stands, if the dry run in `nf-test-changes` fails, the `nf-test` jobs are skipped rather than failed, so `confirm-pass` sees no failure and passes even though no test ran. Once `confirm-pass` is required, such a PR could be merged. With `nf-test-changes` added, a failed dry run fails `confirm-pass`, while a PR with no affected tests still passes. `needs: [nf-test]` comes from the nf-core template, which we otherwise follow as-is; consider reporting it upstream to nf-core/tools.
3. Decide whether admins may bypass the rule. The protection currently applies to non-admins only (`enforcement_level: non_admins`). To block everyone, enable "Do not allow bypassing the above settings".
4. Apply the same rule, and the same `confirm-pass` change, to quality-control-pipeline and cnv-post-processing, which use the same `nf-test.yml` design.

**Who:** someone with admin rights on the repository.

### Test starting the pipeline from a later step

_Noted 2026-09-28, BIOINFO-231._

`tests/default.nf.test` only runs the default `genotype` step. Restarting from `normalize`, `annotation`, `inheritance` or `exomiser` with the CSV manifests written by a previous run (`channel_create_csv`, see `docs/output.md`) is a real feature that no test covers. Add it as an nf-test pipeline test rather than in `ci-full-run.yml`, so it gets real checks: for example, a first run with `-profile test`, then a second one with `--step annotation --input <outdir>/csv/normalized_genotypes.csv`, checking that it succeeds and produces the expected outputs.

### Check the official exomiser image on Kubernetes before releasing BIOINFO-232

_Noted 2026-09-28, BIOINFO-231._

BIOINFO-232 (#114) switched `EXOMISER` to the official `exomiser/exomiser-cli:14.0.0-bash` image, whose `ENTRYPOINT` is `/bin/bash`. The `--entrypoint ""` override that makes it work is only set in the `docker` and `podman` profiles. Production runs on Kubernetes. Nextflow's Kubernetes executor is expected to set the pod's `command`, which overrides the image's `ENTRYPOINT`, so it should work without the override. That hasn't been tested, though. Before a release containing BIOINFO-232 reaches production, run the pipeline (or at least the `EXOMISER` step) once on a production-like Kubernetes setup. If exomiser fails with `/bin/bash: /bin/bash: cannot execute binary file` (exit 126), the entrypoint needs clearing for Kubernetes too.
