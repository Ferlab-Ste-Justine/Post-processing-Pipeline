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
