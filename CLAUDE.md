# CLAUDE.md

This file gives Claude Code the context it needs to work effectively in this repository.

## Project overview

`Ferlab-Ste-Justine/Post-processing-Pipeline` (manifest name: `Ferlab-Ste-Justine/Post-Processing-Pipeline`) is a Nextflow DSL2 pipeline for family-based variant analysis of GVCFs. It performs joint genotyping, tags low-quality variants, optionally normalizes, annotates with VEP, tags variants by mode of inheritance with slivar, and prioritizes variants with exomiser.

The repo is structured following nf-core conventions. It is _not_ a published nf-core pipeline.

Nextflow version range: `>=23.10.1, <26.0.0`. Pipeline version is tracked in `nextflow.config` (`manifest.version`) and `.nf-core.yml` (`template.version`).

## High-level pipeline flow

The single entry workflow is in `main.nf`, which calls `POSTPROCESSING` in `workflows/postprocessing.nf`. That workflow is gated by the `--step` parameter so the pipeline can be entered at five points:

1. `genotype` (default): standardize input VCFs → optional MNP exclusion → `COMBINEGVCFS` → `GATK4_GENOTYPEGVCFS` → tag artifacts (VQSR for WGS, GATK `VariantFiltration` hard-filtering for WES)
2. `normalize`: starts from filtered VCFs → `SPLIT_MULTIALLELICS` (bcftools norm)
3. `annotation`: starts from normalized VCFs → VEP (`VCF_ANNOTATE_ENSEMBLVEP`); cache is downloaded via `ENSEMBLVEP_DOWNLOAD` when `--download_cache` is set
4. `inheritance`: starts from VEP-annotated VCFs → `SLIVAR_INHERITANCE` (tags by mode of inheritance, detects compound heterozygotes)
5. `exomiser`: starts from annotated/normalized VCFs → `EXOMISER`

Two optional branches run when their tool is included via `--tools` (comma-separated, e.g. `vep,exomiser,slivar`):

- **slivar inheritance** (`isToolIncluded('slivar')` or `--step inheritance`) — tags variants by mode of inheritance and identifies compound hets via `SLIVAR_INHERITANCE`. Requires a `familyPed` column in the samplesheet.
- **exomiser** — only runs for families that have a `familyPheno` phenopacket. Picks WES vs. WGS analysis YAML based on `meta.sequencingType`.

The WES/WGS distinction is load-bearing: it controls both the artifact-tagging method (VQSR vs. hard-filter) and the exomiser analysis file. Sequencing type comes from the `sequencingType` column of the samplesheet.

## Repository layout

```
main.nf                      # Entry point — calls PIPELINE_INITIALISATION, FERLAB_POSTPROCESSING, PIPELINE_COMPLETION
nextflow.config              # Params, profiles, per-process resources, manifest
nextflow_schema.json         # Authoritative parameter schema (use this, not the README)
nf-test.config               # nf-test runner config (profile "test")
workflows/postprocessing.nf  # Main POSTPROCESSING workflow — step gating + inlined stage logic (standardize, MNP handling, artifact tagging, VEP/slivar/exomiser branches); the old helper closures were inlined in v3.0.0 (their names survive only as `ch_output_from_*` channels)
subworkflows/local/          # exclude_mnps, vqsr, slivar_inheritance, channel_create_csv, utils_nfcore_postprocessing_pipeline
subworkflows/nf-core/        # utils_nextflow_pipeline, utils_nfcore_pipeline, utils_nfschema_plugin, vcf_annotate_ensemblvep
modules/local/               # combine_gvcfs, exomiser, gatk4/applyvqsr, slivar/{expr,compoundhets}, split_multiallelics
modules/nf-core/             # bcftools (annotate/filter/norm/view), ensemblvep (vep, download), gatk4 (genotypegvcfs, variantfiltration, variantrecalibrator), tabix
conf/                        # base.config, modules.config, slivar.config, igenomes.config, test.config, test_full.config
containers/                  # Dockerfiles for exomiser and exomiser-13
assets/                      # TestSampleSheet.csv, schema_input.json, slivar-functions.js, exomiser/ (default analysis YAMLs)
docs/                        # usage.md, output.md, reference_data.md
```

## How to run

Typical invocation (from the README):

```bash
nextflow run -c cluster.config Ferlab-Ste-Justine/Post-processing-Pipeline -r "v3.0.0" \
    -params-file params.json \
    --input samplesheet.csv \
    --outdir results/dir \
    --tools vep,exomiser
```

Important conventions:

- Pass parameters via CLI flags or `-params-file` (JSON/YAML). **Do not** put params in a `-c` config file — `-c` is reserved for resource/infrastructure tuning. The `docs/usage.md` and `nextflow.config` comments both call this out.
- `--tools` is a comma-separated list. Membership is checked with `isToolIncluded` / `isVepToolIncluded` / `isExomiserToolIncluded` (in `subworkflows/local/utils_nfcore_postprocessing_pipeline/utils`).
- `--step` defaults to `genotype`. Other valid values: `normalize`, `annotation`, `exomiser`, `inheritance`.

### Test dataset

The test data is expected to be accessible locally under the launch directory. Before testing the pipeline, verify that the test-data directory exists.
The data lives in a private AWS S3 bucket `s3://ferlab-public-dataset/nextflow/Post-Processing-Pipeline/V7/data-test` and in a private CEPH S3 bucket `s3://cqdg-prod-file-import/test-datasets/Post-Processing-Pipeline/V7/data-test`.

### Stub / quick smoke test

```bash
nextflow run Ferlab-Ste-Justine/Post-processing-Pipeline -profile test,docker -stub
```

`-stub` runs the `stub:` block of each process instead of the real `script:` block — useful for verifying wiring without real data or reference downloads.

### Test profile

If running locally:

- Make sure Docker Desktop is installed and running.

```bash
nextflow run Ferlab-Ste-Justine/Post-processing-Pipeline -profile test,docker
```

If running on ARM hardware, add the `arm` profile to pull ARM-compatible images:

```bash
nextflow run Ferlab-Ste-Justine/Post-processing-Pipeline -profile test,docker,arm
```

To clean-up outputs, run `nextflow clean -f`.

### Tests (nf-test)

`nf-test` is the testing framework. Config in `nf-test.config` sets `profile "test"` (add `docker` on the command line, e.g. `--profile test,docker`). nf-core upstream tests are excluded via the `ignore` glob.

If running locally,

- Make sure to run `export NXF_FILE_ROOT=$PWD` to allow nf-core's `nf-test` framework to find test files.

```bash
nf-test test                         # run all tests
nf-test test --profile test,docker --tag pipeline          # run the entire pipeline test
nf-test test modules/local/exomiser  # target one module/subworkflow
```

Test snapshots live alongside each module as `tests/main.nf.test.snap`.

To clean-up test outputs, run `nf-test clean` or manually delete the `.test_output/` directory.

### Linting

CI lint workflow: `.github/workflows/linting.yml` (nf-core lint + nf-test). Run locally with:

```bash
nf-core lint
```

`.nf-core.yml` carries lint overrides — several nf-core-template files are deliberately not present (e.g. `CODE_OF_CONDUCT.md`, nf-core logos, AWS CI workflows) because this is a Ferlab workflow, not a published nf-core pipeline. Don't reintroduce those files; instead update `.nf-core.yml` if you need to change lint behavior.

To format the files before commiting run:

```bash
pre-commit run --all-files
```

## Samplesheet format

Required columns depend on `--step`. See `assets/schema_input.json` for the authoritative schema; `docs/usage.md` has worked examples. Summary:

- Default (`genotype`): `familyId, sample, sequencingType, gvcf` (+ optional `familyPheno`, `familyPed`)
- `normalize`: `familyId, sample, sequencingType, vcf` (+ optional `tbi`)
- `annotation` / `exomiser`: `familyId, sequencingType, vcf` (+ optional `tbi`, `familyPheno` required for exomiser)

`sequencingType` must be `WES` or `WGS`. `familyPheno` (phenopacket YAML/JSON) must be identical for every member of a family; same rule for `familyPed`.

## Working in this codebase

A few patterns worth knowing before editing:

- **Channel shape convention.** Most VCF channels carry `[meta, vcf, tbi]`. After a `BCFTOOLS_*` / `GATK4_*` call, the index is usually emitted separately and joined back: `out.vcf.join(out.tbi)`.
- **Per-process resources** live in `nextflow.config` under `process { withName: '...' }`, gated by the `check_max(...)` function and the `max_cpus / max_memory / max_disk / max_time` params. When adding a new process, follow the same `errorStrategy = 'retry'` + `task.attempt`-scaled pattern.
- **Hard filters** for WES are defined as a list of `[name, expression]` pairs in `nextflow.config` (`params.hardFilters`). VQSR tranches/annotations are in the same block.
- **Reference inputs** are resolved at the top of `POSTPROCESSING` from `params.referenceGenome` + `params.referenceGenomeFasta` (the Fasta lives _inside_ the referenceGenome directory; `.fai` and `.dict` are derived from the Fasta path).
- **Adding an nf-core module:** use `nf-core modules install <tool>` so `modules.json` stays consistent. Local-only logic goes under `modules/local/`.
- **Schema and params stay in sync.** `nextflow_schema.json` is the source of truth for parameter validation (driven by the `nf-schema` plugin, `nf-schema@2.1.0` — migrated from `nf-validation` in v3.0.0). When adding a param, update both `nextflow.config` defaults and the schema.

## Outputs

`--outdir` is required. VEP and exomiser outputs can be split to separate directories via `--vep_outdir` and `--exomiser_outdir`. Per-step CSV manifests of published results are produced by the `channel_create_csv` subworkflow (added in v2.9.0); these are what makes restarting from intermediate steps work — the CSV from a previous run is a valid `--input` for the next step. Pipeline run metadata, configs, timeline/report/trace/dag are written to `${outdir}/pipeline_info/`.

See `docs/output.md` for the full output layout.

## Pointers

- Parameter documentation: `nextflow_schema.json` (authoritative). README/usage docs intentionally avoid duplicating parameter details.
- Reference data setup: `docs/reference_data.md`.
- Output layout: `docs/output.md`.
- Changelog and version history: `CHANGELOG.md`.
- PR templates: `.github/PULL_REQUEST_TEMPLATE.md`.
