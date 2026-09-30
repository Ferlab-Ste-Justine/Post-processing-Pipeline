# Ferlab-Ste-Justine/Post-Processing-Pipeline: Contributing Guidelines

Hi there!
Many thanks for taking an interest in improving Ferlab-Ste-Justine/Post-Processing-Pipeline.

If you haven't already, we recommend creating a GitHub issue to describe your task. Please use the pre-filled template to save time.

Please do your best to follow the guidelines defined here. If you are unsure about the current standards or need support, feel free to ask for help in the [#bioinfo](https://cr-ste-justine.slack.com/archives/C074VMACUD9slack) Slack channel.

We also hold a few notion pages as documentation:

- [Nf-core guidelines](https://www.notion.so/ferlab/Nf-core-guidelines-43b08da49e8f49b2968f17a34adc783a)
- [Help with samplesheet and schemas](https://www.notion.so/ferlab/Nf-core-schema-input-and-parsing-Samplesheet-files-29603f232c7f4f018fc337f2d1d16a4c)
- [Notes for module/subworkflow building](https://www.notion.so/ferlab/Notes-for-nf-core-modules-subworkflows-1cb401615ea149278b87c12e9284745d)

## Contribution workflow

We follows the guidelines outlined by Ferlab for our git flow, which are detailed in the [Developer Handbook](https://www.notion.so/ferlab/Developer-Handbook-ca9d689d8aca4412a78eafa2dfa0f8a8).

Please ensure that you adhere to the conventions for branch names and commit messages.

Pull requests are squash-merged, so the PR title becomes the commit message on `main`. CI checks that it follows `<type>: <TICKET-123> <description>`, e.g. `fix: BIOINFO-231 pin actions/checkout`.

If applicable, use `nf-core pipelines schema build` to add new parameters to the pipeline JSON schema. This requires [nf-core tools](https://github.com/nf-core/tools), in the version pinned in `.nf-core.yml` (`nf_core_version`).

## Tests

When you create a pull request with changes, [GitHub Actions](https://github.com/features/actions) will run automatic tests.

A pull-request should only be merged when all these tests are passing.

There are 4 checks, described below. To run the same checks locally before pushing, use `bash scripts/run-test-suite.sh`.

### Lint tests

The lint tests (`.github/workflows/linting.yml`) run on every pull request:

- `pre-commit run --all-files`: prettier, trailing whitespace and end-of-file fixes, and editorconfig-checker against `.editorconfig`. The check fails if a hook would change a file, so run it locally and commit the result.
- `nf-core pipelines lint`, with `--release` for pull requests into `main`. CI installs the nf-core tools version pinned in `.nf-core.yml` (`nf_core_version`). Ensure that no lint test fails and that no additional warnings appear compared to the main branch.

At Ferlab, we don't enforce all linting rules. If a test should be ignored, it should be added to .nf-core.yml.

### Pipeline tests

This test (`.github/workflows/ci-full-run.yml`) runs the pipeline with the minimal test dataset (`-profile test,docker`) and checks that it completes successfully. CI downloads the test data from S3 with the `.github/actions/copy-test-data` action.

These tests are run with the minimum Nextflow version stated in the pipeline code (`manifest.nextflowVersion`) and with a more recent version (see the workflow's `NXF_VER` matrix).

You are encouraged to also test locally and in integration environments. Reach out to the Ferlab bioinformatics team if you need help with this. You can find example commands in the test.config
configuration file.

### nf-test tests

This test (`.github/workflows/nf-test.yml`) runs the nf-test tests. On pull requests, it only runs the tests affected by the submitted changes. Releases and manual runs run the whole suite.

The tests are run with the minimum Nextflow version, a more recent version and the latest Nextflow release. A failure with the latest release is reported as a warning but doesn't fail the check.

### PR title

`.github/workflows/ci-pr-title-lint.yml` checks that the pull request title follows the format described under [Contribution workflow](#contribution-workflow). If it fails, edit the title on GitHub; the check reruns by itself.

## Pipeline contribution conventions

To make the Ferlab-Ste-Justine/Post-Processing-Pipeline code and processing logic more understandable for new contributors and to ensure quality, we try to follow nf-core standards as much as possible.

They are described below. Try to follow them as much as possible. If you are unsure, feel free to reach out to the bioinformatics team.

### Adding a new step

If you wish to contribute a new step, please use the following coding standards:

1. Define the corresponding input channel into your new process from the expected previous process channel
2. Write the process block (see below).
3. Define the output channel if needed (see below).
4. Add any new parameters to `nextflow.config` with a default (see below).
5. Add any new parameters to `nextflow_schema.json` with help text (via the `nf-core pipelines schema build` tool).
6. Add sanity checks and validation for all relevant parameters.
7. Perform local tests to validate that the new code works as expected.
8. If applicable, add a new test command in `.github/workflows/ci-full-run.yml`.
9. If applicable, write nf-test unit tests
10. Add a description of the output files if relevant to `docs/output.md`.

### Default values

Parameters should be initialised / defined with default values in `nextflow.config` under the `params` scope.

Once there, use `nf-core pipelines schema build` to add to `nextflow_schema.json`.

### Default processes resource requirements

Sensible defaults for process resource requirements (CPUs / memory / time) for a process should be defined in `conf/base.config`. These should generally be specified generic with `withLabel:` selectors so they can be shared across multiple processes/steps of the pipeline. A nf-core standard set of labels that should be followed where possible can be seen in the [nf-core pipeline template](https://github.com/nf-core/tools/blob/master/nf_core/pipeline-template/conf/base.config), which has the default process as a single core-process, and then different levels of multi-core configurations for increasingly large memory requirements defined with standardised labels.

The process resources can be passed on to the tool dynamically within the process with the `${task.cpus}` and `${task.memory}` variables in the `script:` block.

### Naming schemes

Please use the following naming schemes, to make it easy to understand what is going where.

- initial process channel: `ch_output_from_<process>`
- intermediate and terminal channels: `ch_<previousprocess>_for_<nextprocess>`

### Nextflow version bumping

If you are using a new feature from core Nextflow, you may bump the minimum required version of nextflow in the pipeline with: `nf-core pipelines bump-version --nextflow [min-nf-version]`

Then check that the `NXF_VER` matrices in `.github/workflows/nf-test.yml` and `.github/workflows/ci-full-run.yml` include the new minimum (nf-core lint fails if `nf-test.yml` doesn't test it), and update the Nextflow version installed in `.github/workflows/linting.yml`.
