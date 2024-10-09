# Ferlab-Ste-Justine/Post-processing-Pipeline: Usage

>  _Parameters documentation is available in the [pipeline schema](../nextflow_schema.json)._
> _You can use the command `nf-core schema docs` to output parameters documentation._
> _To avoid duplication of information, we minimize parameters details in markdown files._
> _Currently, we only add context for the reference data parameters and provide parameter summaries for convenience._

## Introduction

The Ferlab-Ste-Justine/Post-processing-Pipeline is a bioinformatics pipeline designed for family-based analysis of GVCFs from multiple samples. It performs joint genotyping, tags low-quality variants, and optionally annotates the final VCF using VEP and/or Exomiser. This document provides instructions on how to prepare input files, run the pipeline, and understand the output.


## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use the `--input` parameter to specify its location. The samplesheet has to be a comma separated file (.csv).

The samplesheet must contains the following columns at the minimum: 
- *familyId*: The identifier used for the sample family
- *sample*: The identifier used for the sample
- *sequencingType*: Must be either WES (Whole Exome Sequencing) or WGS (Whole Genome Sequencing)
- *gvcf*: Path to the sample .gvcf file

Additionnally, there is an optional *phenoFamily* column that can contain a .yml/.json file providing phenotype 
information on the family in phenopacket format. This column is only necessary if using the exomiser tool.


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
> In the case of Whole Genome Sequencing, VQSR (Variant Quality Score Recalibration) is used.
> In the case of Whole Exome Sequencing, VQSR is replaced by a hard filtering approach as VQSR cannot be applied in this case.
> Additionally, a different analysis file will be used when running the exomiser tool based on the sequencing type.

## Reference Data

Reference files are essential at various stages of the workflow, including joint-genotyping, VQSR, the Variant Effect Predictor (VEP), and exomiser. 

These files must be correctly downloaded and specified through pipeline parameters. For more details about how to this, see 
[reference_data.md](reference_data.md).


## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run -c cluster.config Ferlab-Ste-Justine/Post-processing-Pipeline -r "v2.1.0" \
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

:::warning
Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).
:::


### Tools

You can include additional analysis in your pipeline  via the `tools` parameter. Currently, the pipeline supports 
two tools: `vep` (Variant Effect Predictor) and `exomizer`. 

VEP is a widely used tool for annotating genetic variants with information such as gene names, 
variant consequences, and population frequencies. It provides valuable insights into the functional impact 
of genetic variants.

Exomiser, on the other hand, is a tool specifically designed for the analysis of rare genetic diseases. It 
integrates phenotype data with variant information to prioritize variants that are likely to be disease-causing. 
This can greatly assist in the identification of potential disease-causing variants in exome sequencing data.


### Stub mode and quick tests

The `-stub` (or `-stub-run`) option can be added to run the "stub" block of processes instead of the "script" block. This can be helpful for testing.


To test your setup in stub mode, simply run `nextflow run Ferlab-Ste-Justine/Post-processing-Pipeline -profile test,docker -stub`. 

For tests with real data, see documentation in the [test configuration profile](conf/test.config)

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull ferlab/postprocessing
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [ferlab/postprocessing releases page](https://github.com/ferlab/postprocessing/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

:::tip
If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.
:::


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
| `broad` | _Required_ | Path to the directory containing Broad reference data |
| `intervalsFile` | _Required_ | Filename of the genome intervals list, within the specified `broad` directory |
| `tools` | _Optional_ | Additional tools to run separated by commas. Supported tools are `vep` and `exomiser` |
| `vepCache` | _Optional_ | Path to the vep cache data directory |
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
