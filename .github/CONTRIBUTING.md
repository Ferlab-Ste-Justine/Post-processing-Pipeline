# ferlab/postprocessing: Contributing Guidelines

Hi there!
Many thanks for taking an interest in improving ferlab/postprocessing.

If you haven't already, we recommend creating a GitHub issue to describe your task. Please use the pre-filled template to save time.

Please do your best to follow the guidelines defined here. If you are unsure about the current standards or need support, feel free to ask for help in the [#bioinfo](https://cr-ste-justine.slack.com/archives/C074VMACUD9slack) Slack channel.

We also hold a few notion pages as documentation:
- [Nf-core guidelines](https://www.notion.so/ferlab/Nf-core-guidelines-43b08da49e8f49b2968f17a34adc783a)
- [Help with samplesheet and schemas](https://www.notion.so/ferlab/Nf-core-schema-input-and-parsing-Samplesheet-files-29603f232c7f4f018fc337f2d1d16a4c)
- [Notes for module/subworkflow building](https://www.notion.so/ferlab/Notes-for-nf-core-modules-subworkflows-1cb401615ea149278b87c12e9284745d)

## Contribution workflow

We follows the guidelines outlined by Ferlab for our git flow, which are detailed in the [Developer Handbook](https://www.notion.so/ferlab/Developer-Handbook-ca9d689d8aca4412a78eafa2dfa0f8a8).

Please ensure that you adhere to the conventions for branch names and commit messages.

If applicable, use `nf-core schema build` to add new parameters to the pipeline JSON schema. This requires [nf-core tools](https://github.com/nf-core/tools) version 1.10 or higher.

## Tests

When you create a pull request with changes, [GitHub Actions](https://github.com/features/actions) will run automatic tests.

A pull-request should only be merged when all these tests are passing.

There are 3 types of tests run, that are described below.

### Lint tests

The lint test will run the nf-core linter, i.e. the following command and check for errors/warnings.
`nf-core lint`

It is currently deactivated, but we highly recommend to run it locally. Ensure that no lint test fails and that no additional warnings appear compared to the main branch.

At Ferlab, we don't enforce all linting rules. If a test should be ignored, it should be added to .nf-core.yml.


### Pipeline tests

This test runs the pipeline with a minimal set of test data. It only checks that the pipeline can run successfully. Since our test setup is not fully ready yet, it runs in stub mode at the moment.

These tests are run both with the latest available version of `Nextflow` and also the minimum required version that is stated in the pipeline code.

You are encouraged to test in non-stub mode locally and in integration environments. Reach out to the Ferlab bioinformatics team if you need help with this. You can find example commands in the test.config
configuration file.


### nf-test tests

This test runs unit tests with nf-test. For now, for performance reasons, it only runs tests applicable to the submitted changes and tests tagged with the keyword "local".

The tests are only run with the Nextflow version expected in production, also for performance reasons.


## Pipeline contribution conventions

To make the ferlab/postprocessing code and processing logic more understandable for new contributors and to ensure quality, we try to follow nf-core standards as much as possible.

They are described below. Try to follow them as much as possible. If you are unsure, feel free to reach out to the bioinformatics team.


### Adding a new step

If you wish to contribute a new step, please use the following coding standards:

1. Define the corresponding input channel into your new process from the expected previous process channel
2. Write the process block (see below).
3. Define the output channel if needed (see below).
4. Add any new parameters to `nextflow.config` with a default (see below).
5. Add any new parameters to `nextflow_schema.json` with help text (via the `nf-core schema build` tool).
6. Add sanity checks and validation for all relevant parameters.
7. Perform local tests to validate that the new code works as expected.
8. If applicable, add a new test command in `.github/workflow/ci.yml`.
9. If applicable, write nf-test unit tests
10. Add a description of the output files if relevant to `docs/output.md`.

### Default values

Parameters should be initialised / defined with default values in `nextflow.config` under the `params` scope.

Once there, use `nf-core schema build` to add to `nextflow_schema.json`.

### Default processes resource requirements

Sensible defaults for process resource requirements (CPUs / memory / time) for a process should be defined in `conf/base.config`. These should generally be specified generic with `withLabel:` selectors so they can be shared across multiple processes/steps of the pipeline. A nf-core standard set of labels that should be followed where possible can be seen in the [nf-core pipeline template](https://github.com/nf-core/tools/blob/master/nf_core/pipeline-template/conf/base.config), which has the default process as a single core-process, and then different levels of multi-core configurations for increasingly large memory requirements defined with standardised labels.

The process resources can be passed on to the tool dynamically within the process with the `${task.cpus}` and `${task.memory}` variables in the `script:` block.

### Naming schemes

Please use the following naming schemes, to make it easy to understand what is going where.

- initial process channel: `ch_output_from_<process>`
- intermediate and terminal channels: `ch_<previousprocess>_for_<nextprocess>`

### Nextflow version bumping

If you are using a new feature from core Nextflow, you may bump the minimum required version of nextflow in the pipeline with: `nf-core bump-version --nextflow . [min-nf-version]`