#!/usr/bin/env bash
# Automated pre-push checks: nf-test suite and nf-core lint. Fail-fast
# (set -e) so the first broken step stops the script.
#
# pre-commit (prettier, trailing-whitespace, end-of-file-fixer) is
# deliberately NOT included here -- it's already wired into
# .github/workflows/linting.yml and runs automatically on every PR, so
# there's no need to duplicate it locally too.
#
# Note on dependencies: the dry-run and lint steps need nothing but the
# tools themselves, but the real (non-dry-run) nf-test suite still spins up
# Docker containers, and its pipeline-level tests (tests/default.nf.test)
# need the S3 test dataset synced locally (data-test/ -- see CLAUDE.md's
# "Test dataset" section). This script does NOT include the ad hoc, manually
# -inspected `nextflow run` smoke tests -- see scripts/run-smoke-tests.sh for
# those.
#
# Usage: scripts/run-test-suite.sh

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
export NXF_FILE_ROOT="$PWD"

require() {
    command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found on PATH." >&2; exit 1; }
}
require nf-test
require nf-core

step() { echo; echo "==> $1"; }

# Remember that running 'nf-test test' essentially discovers and run .nf.test files
step "[1/3] nf-test dry-run (syntax check only, no execution)"
nf-test test --dryRun

step "[2/3] nf-test full suite (--profile test,docker)"
nf-test test --profile test,docker

step "[3/3] nf-core pipelines lint --release"
nf-core pipelines lint --release

echo
echo "All checks passed."
