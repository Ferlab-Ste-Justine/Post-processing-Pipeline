# ferlab/postprocessing: Output

## Introduction

This document describes the output produced by the pipeline.

The directories described below will be created in the output directory after the pipeline has finished. 

For the vep and exomiser steps, it is possible to specify custom output directories via `vep_outdir` and `exomiser_outdir` parameters. If these parameters are not specified, the output for these steps will be included in the main output directory defined by the `outdir` parameter. 

Unless stated otherwise, this document assumes that the default output locations are used for vep and exomiser steps.

## Overview

The pipeline output is saved step-by-step in the output directory as each step is completed. Below, we provide a description of the output folders corresponding to the main steps, as well as the `pipeline_info` folder, which contains details about the submitted job.


- [ferlab/postprocessing: Output](#ferlabpostprocessing-output)
  - [Introduction](#introduction)
  - [Overview](#overview)
  - [Directory Structure](#directory-structure)
  - [Output](#output)
  - [Pipeline Information: pipeline\_info](#pipeline-information-pipeline_info)
  - [VEP Step: ensemblvep](#vep-step-ensemblvep)
  - [Exomiser Step: exomiser](#exomiser-step-exomiser)

## Directory Structure

The output directory structure is as follows:

```
{outdir}
├── pipeline_info/
├── csv/
├── normalized_genotypes/
├── ensemblvep/
├── exomiser/
...
```

The `pipeline_info` subdirectory contains details about the pipeline execution and metadata relevant to reproducibility, performance optimization and troubleshooting.

The `csv` subdirectory includes auto-generated index csv files for each of the analysis steps included. They keep the original output channel structure. They are used by the pipeline to further process/re-start from previously generated output.

The `normalized_genotypes` subdirectory contains the output after running GATK GenotypeGVCFs and normalizing the variants and will appear if `save_genotyped = true`.

The `ensemblvep` subdirectory contains the output after running vep and will appear only if vep is specified in the `tools` parameters.

The `exomiser` subdirectory contains the output after running exomiser and will appear only if exomiser is specified in the `tools` parameters.


## Output

By default, if vep and/or exomiser are included as tools, **only annotated VCFs (ensemblvep) and Exomiser results are published.** If no tools are included, the final joint-genotyped results are published.

If needed, you can set `save_genotyped` to `true` to publish the normalized joint-genotyping results or `publish_all` to `true` to publish the outputs from all pipeline steps. These outputs will be saved in subdirectories within the main output directory specified by the `outdir` parameter. The names of the subdirectories will match the nextflow process names.

> [!IMPORTANT]
> We don't recommend using `publish_all = true` in production. This is primarily useful for testing, debugging or troubleshooting.

## Pipeline Information: pipeline_info

Here we describe in more details the content of the `pipeline_info `subdirectory. It should contain the following:

```
|_ pipeline_info
   |_ configs
      |_ nextflow.config
          ... 
   |_ execution_report_2024-12-09_12-03-20.html
   |_ execution_timeline_2024-12-09_12-03-20.html
   |_ execution_trace_2024-12-09_12-03-20.txt
   |_ params_2024-12-09_12-03-23.json
   |_ pipeline_dag_2024-12-09_12-03-20.html
   |_ metadata.txt
   |_ nextflow.log
```

  The timestamps that appear in some files are in the user's timezone.

  The `configs` folder contains copies of configuration files used. This includes the default `nextflow.config` file as well as any additional configuration files passed as parameters.

  The files prefixed by `execution_`are reports automatically generated by nextflow. These reports allow you to troubleshoot errors with the  pipeline execution and provide inofrmation such as launch commands, run times and resource usage. You can refer to the [nextflow documentation](https://www.nextflow.io/docs/latest/reports.html) for more details about these reports.
  
  The file prefixed by `params` contains the parameters used by the pipeline.

  The file prefixed by `pipeline_dag` contains a diagram of the pipeline steps.

  The `metadata.txt` file contains various information relevant for reproducibility, such as the original command line, the name of the branch / revision used, the username associated to the command, a list of configuration files passed, the nextflow work directory, etc.

  The `nextflow.log` file is a copy the nextflow log file.  Note that it will miss logs written after the `workflow.onComplete` handler is run.

## Annotation Step: ensemblvep

The `ensemblvep` subdirectory contains the output of the pipeline after the vep step. 

```
|_ ensemblvep/
  |_ variants.family1.snv.vep.vcf.gz
  |_ variants.family1.snv.vep.vcf.gz.tbi
  ...
```

It contains one pair of `vcf.gz`, `vcf.gz.tbi` files per family. Specifically, we use the following naming scheme:
- `variants.<FAMILY_ID>.snv.vep.vcf.gz`
- `variants.<FAMILY_ID>.snv.vep.vcf.gz.tbi`

The family ID should match the family ID in the input sample sheet.

Note that, if vep is not specified in the `tools` parameter, the vep step will not be executed, and the `ensemblvep` subdirectory will not be created.

By default, VEP output is saved in the `ensemblvep` subfolder within the main output directory. To save the output to a different location, use the `vep_outdir` parameter. 
In this case, the .vcf.gz and .vcf.gz.tbi files will be saved at the root of the specified location.

## Exomiser Step: exomiser

The `exomiser` subdirectory contains the output fo the pipeline after the exomiser step.

```
|_ exomiser
   |_ family1.exomiser.genes.tsv
   |_ family1.exomiser.html
   |_ family1.exomiser.json
   |_ family1.exomiser.variants.tsv
   |_ family1.exomiser.vcf.gz
   |_ family1.exomiser.vcf.gz.tbi
  ...   
```

It should contains a set of 6 files per family.  Specifically, we use the following naming scheme:
- `<FAMILY_ID>.exomiser.genes.tsv`
- `<FAMILY_ID>.exomiser.html`
- `<FAMILY_ID>.exomiser.json`
- `<FAMILY_ID>.exomiser.variants.tsv`
- `<FAMILY_ID>.exomiser.vcf.gz`
- `<FAMILY_ID>.exomiser.vcf.gz.tbi`

The family ID should match the family ID in the input sample sheet.

For more details about the content of each of these files, you can have a look at the exomiser documentation [here](https://exomiser.readthedocs.io/en/latest/result_interpretation.html)

> [!NOTE]
> If exomiser is not specified in the `tools` parameter, the exomiser step will not be executed, and the `exomiser` subdirectory will not be created.

By default, exomiser output is saved in the `exomiser` subfolder within the main output directory. To save the output to a different location, use the `exomiser_outdir` parameter. In this case, the exomiser files will be written at the root of the specified location.
