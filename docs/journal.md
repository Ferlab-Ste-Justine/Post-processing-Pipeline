# Journal

Running notes on decisions, open questions and follow-ups for this pipeline.

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
