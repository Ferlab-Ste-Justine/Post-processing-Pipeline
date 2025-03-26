# Ferlab-Ste-Justine/Post-processing-Pipeline: Usage

>  _Parameters documentation is available in the [pipeline schema](../nextflow_schema.json)._
> _You can use the command `nf-core schema docs` to output parameters documentation._
> _To avoid duplication of information, we minimize parameters details in markdown files._
> _Currently, we only add context for the reference data parameters and provide parameter summaries for convenience._

## Introduction

The Ferlab-Ste-Justine/Post-processing-Pipeline is a bioinformatics pipeline designed for family-based analysis of GVCFs from multiple samples. It performs joint genotyping, tags low-quality variants, and optionally annotates the final VCF using VEP and/or Exomiser. This document provides instructions on how to prepare input files, run the pipeline, and understand the output.


## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use the `--input` parameter to specify its location. The samplesheet has to be a comma separated file (`.csv`).

The samplesheet must contains the following columns at the minimum: 
- *familyId*: The identifier used for the sample family
- *sample*: The identifier used for the sample
- *sequencingType*: Must be either WES (Whole Exome Sequencing) or WGS (Whole Genome Sequencing)
- *gvcf*: Path to the sample `.gvcf.gz` file

Additionally, there is an optional *phenoFamily* column that can contain a `.yml/.json` file providing phenotype information on the family in phenopacket format. This column is only necessary if using the exomiser tool. If exomiser is enabled, it must consistently contain either an empty string or the same phenopacket file for all members of the family. For more details, refer to the exomiser tool section below.

**sample.csv**
```csv
**familyId**,**sample**,**sequencingType**,**gvcf**,**phenoFamily**
CONGE-XXX,01,WES,CONGE-XXX-01.hard-filtered.gvcf.gz,CONGE-XXX.pheno.yml
CONGE-XXX,02,WES,CONGE-XXX-02.hard-filtered.gvcf.gz,CONGE-XXX.pheno.yml
CONGE-XXX,03,WES,CONGE-XXX-03.hard-filtered.gvcf.gz,CONGE-XXX.pheno.yml
CONGE-YYY,01,WGS,CONGE-YYY-01.hard-filtered.gvcf.gz,CONGE-YYY.pheno.yml
CONGE-YYY,02,WGS,CONGE-YYY-02.hard-filtered.gvcf.gz,CONGE-YYY.pheno.yml
CONGE-YYY,03,WGS,CONGE-YYY-03.hard-filtered.gvcf.gz,CONGE-YYY.pheno.yml
```

> [!NOTE]
> The sequencing type (WES or WGS) will determine the variant filtering approach used by the pipeline.
> In the case of Whole Genome Sequencing (WGS), VQSR (Variant Quality Score Recalibration) is used.
> In the case of Whole Exome Sequencing (WES), VQSR is replaced by a hard filtering approach as VQSR cannot be applied in this case.
> Additionally, a different analysis file will be used when running the exomiser tool based on the sequencing type.

## Reference Data

Reference files are essential at various stages of the workflow, including joint-genotyping, VQSR, the Variant Effect Predictor (VEP), and exomiser. 

These files must be correctly downloaded and specified through pipeline parameters. For more details about how to do this, see [reference_data.md](reference_data.md).


## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run -c fusion.config Ferlab-Ste-Justine/Post-processing-Pipeline -r "v2.7.0" \
    -params-file params.json  \
   --input samplesheet.csv \
   --outdir results/dir \
   --tools vep,exomiser
```


Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file (json or yaml).

> <b>WARNING</b>:  
Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

### Skip exclude MNPs

At the beginning of our workflow, we separate MNPs into individual SNPs.  

You can optionally skip this step by setting the `exclude_mnps` parameter to `false` (default is `true`).

Note that MNPs are not supported by the VQSR procedure, so you cannot skip this step if you have whole genome data.

### Tools

You can include additional analysis in your pipeline  via the `tools` parameter. Currently, the pipeline supports 
two tools: `vep` (Variant Effect Predictor) and `exomiser`. 

VEP is a widely used tool for annotating genetic variants with information such as gene names, 
variant consequences, and population frequencies. It provides valuable insights into the functional impact of genetic variants.

Exomiser, on the other hand, is a tool specifically designed for the analysis of rare genetic diseases. It integrates phenotype data with variant information to prioritize variants that are likely to be disease-causing. 
This can greatly assist in the identification of potential disease-causing variants in exome sequencing data.

### Exomiser tool

To run exomiser, activate it via the `tools` parameter (see section above). 

Additionally, provide the exomiser phenopacket file in the samplesheet for each family member in the phenoFamily column. If the phenopacket file is not specified for a family, exomiser will be skipped for that family.

Note that the value for the phenoFamily column must always be identical for the same family.

#### Exomiser input data

By default, both vep and exomiser steps, if applicable, run in parallel and consume the output of the normalization step.

To have the Exomiser step start from the VEP output instead, set the parameter `exomiser_start_from_vep` to `true`. In this case, the vep and exomiser steps will run sequentially.

Note that the parameter `exomiser_start_from_vep` will be ignored if vep is not specified via the `tools` parameter.

#### Exomiser CLI options

We typically allow passing extra arguments in our process scripts via the process `task.ext` directive (`task.ext.args` key).

When using the exomiser process, it's important to distinguish between regular CLI options and options that correspond to properties normally specified in the application.properties file.

Regular CLI options should be added to `task.ext.args`.

Options that correspond to application properties (e.g., typically `--exomiser.some-property=value`) must be added to `task.ext.application_properties_args`. These options need to be grouped at the end of the exomiser command to ensure that regular exomiser cli options are parsed correctly.

### Customize versions and commands

If needed, it is possible to customize the options passed to the vep command by overriding the ext.args directive for the
ENSEMBLVEP_VEP process. See [conf/modules.config](../conf/modules.config).


### Stub mode and quick tests

The `-stub` (or `-stub-run`) option can be added to run the "stub" block of processes instead of the "script" block. This can be helpful for testing.


To test your setup in stub mode, simply run `nextflow run Ferlab-Ste-Justine/Post-processing-Pipeline -profile test,docker -stub`. 

For tests with real data, see documentation in the [test configuration profile](conf/test.config)

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull Ferlab-Ste-Justine/Post-processing-Pipeline
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [Ferlab-Ste-Justine/Post-processing-Pipeline releases page](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/tags) and find the latest pipeline version - numeric only (eg. `v2.7.0`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r v2.7.0`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> <b>TIP</b>:  
If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.



### Core Nextflow arguments
- Use the `-profile` parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments (e.g., docker, singularity, conda). Multiple profiles can be loaded in sequence, e.g., `-profile test,docker`.
- Use the `-resume` parameter to restart a pipeline from where it left off. This can save time by using cached results from previous runs.
- You can specify a custom configuration file using the `-c` parameter. This is useful to set configuration specific to your execution environment and change requested resources for a process.

For more detailed information, please refer to the [official Nextflow documentation](https://www.nextflow.io/docs/latest/index.html).


### Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

### Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
To limit this, you can use the `NXF_OPTS` environment variable:

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

Parameters summary
-----

| Parameter name | Required? | Description |
| --- | --- | --- |
| `input` | _Required_ | Path to the input file |
| `outdir` | _Required_ | Path to the output directoy |
| `referenceGenome` |  _Required_ | Path to the directory containing the reference genome data |
| `referenceGenomeFasta` | _Required_ | Filename of the reference genome .fasta file, within the specified `referenceGenome` directory |
| `dbsnpFile` | _Optional_ | Path to dbsnp file. If specified, will be used to add ids in the ID column of output vcf files. |
| `dbsnpFileIndex` | _Optional_ | Path to dbsnp file index. Must be specified if the dbsnpFile parameter is specified. |
| `broad` | _Optional_ | Path to the directory containing Broad reference data (for VQSR) |
| `intervalsFile` | _Optional_ | Path to the file containg the genome intervals list on which to operate |
| `tools` | _Optional_ | Additional tools to run separated by commas. Supported tools are `vep` and `exomiser` |
| `vep_cache` | _Optional_ | Path to the vep cache data directory |
| `vep_cache_version` | _Optional_ | Version of the vep cache. e.g. `111` |
| `vep_genome` | _Optional_ | Genome assembly version of the vep cache  |
| `download_cache` | _Optional_ | Download vep cache (default: false) |
| `outdir_cache` | _Optional_ |  Path to write the cache to. If not declared, cache will be written to `<outputdir>/cache/` |
| `exclude_mnps` | _Optional_ | Replace MNPs by individual SNPs (default: true). Must be true on whole genome data. |
| `exomiser_data_dir` | _Optional_ | Path to the exomiser reference data directory |
| `exomiser_genome` | _Optional_ | Genome assembly version to be used by exomiser(`hg19` or `hg38`) |
| `exomiser_data_version` | _Optional_ | Exomiser data version (e.g., `2402`)|
| `exomiser_cadd_version` | _Optional_ | Version of the CADD data to be used by exomiser (e.g., `1.7`) |
| `exomiser_cadd_indel_filename`|	_Optional_ | Filename of the exomiser CADD indel data file (e.g., `gnomad.genomes.r4.0.indel.tsv.gz`) |
| `exomiser_cadd_snv_filename`|	_Optional_ | Filename of the exomiser CADD snv data file (e.g., `whole_genome_SNVs.tsv.gz`) |
| `exomiser_remm_version` | _Optional_ | Version of the REMM data to be used by exomiser (e.g., `0.3.1.post1`)|
| `exomiser_remm_filename` | _Optional_	| Filename of the exomiser REMM data file (e.g., `ReMM.v0.3.1.post1.hg38.tsv.gz`) |
| `exomiser_analysis_wes` | _Optional_ | Path to the exomiser analysis file for WES data, if different from the default |
| `exomiser_analysis_wgs` | _Optional_ | Path to the exomiser analysis file for WGS data, if different from the default |
| `exomiser_start_from_vep` | _Optional_ | If `true` (default `false`), run the exomiser analysis on the VEP annotated VCF file. Ignored if vep is not activated via `tools` parameter. |
