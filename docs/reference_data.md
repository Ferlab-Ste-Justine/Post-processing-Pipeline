# Ferlab-Ste-Justine/Post-processing-Pipeline: Reference Data

Reference files are essential at various steps of the pipeline, including joint-genotyping, VQSR, the Variant Effect Predictor (VEP), and exomiser. 

These files must be correctly downloaded and specified through pipeline parameters. This document provides a comprehensive list of the required reference files and explains how to set the pipeline parameters appropriately.

## Reference Genome
The `referenceGenome` parameter specifies the directory containing the reference genome files.

This directory should contain the following files:
- The reference genome FASTA file (e.g., `Homo_sapiens_assembly38.fasta`). This filename must be specified with the `referenceGenomeFasta` parameter.
- The reference genome FASTA file index (e.g., `Homo_sapiens_assembly38.fasta.fai`). Its location will be automatically derived by appending `.fai` to the `referenceGenomeFasta` parameter.
- The reference genome dictionary file (e.g., `Homo_sapiens_assembly38.dict`). Its location will be automatically derived by replacing the `.fasta` file extension of the `referenceGenomeFasta` parameter with `.dict`.

## DBSNP reference data
The `dbsnpFile` and `dbsnpFileIndex` parameters specify the path to a dbsnp file and it's index, respectively.
If specified, dbsnp ids will be added in the ID column of the output vcf files in the GenotypeGVCFs step.

Both parameters are null by default. Note that, if specifying `dbsnpFile`, it is mandatory to specify `dbsnpFileIndex`.

## Broad reference data (VQSR)
The `broad` parameter specifies the directory containing the reference data files for VQSR. 
Note that the VQSR step applies only to whole genome data, so you need to specify the broad parameter only if you have whole genome data.

We chose the name `broad` because this data is from the [Broad Institute](https://www.broadinstitute.org/), a collaborative research institution known 
for its contributions to genomics and biomedical research.

Files can be downloaded using this link: [GATK Ressource Bundle](https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0/)

The broad directory must contain the following files:
  - HapMap file : hapmap_3.3.hg38.vcf.gz
  - 1000G omni2.5 file : 1000G_omni2.5.hg38.vcf.gz
  - 1000G reference file : 1000G_phase1.snps.high_confidence.hg38.vcf.gz
  - SNP database : Homo_sapiens_assembly38.dbsnp138.vcf.gz

These are all highly validated variance ressources currently required by VQSR. 
***The file names are not configurable and are currently hard coded in the pipeline***.

Extra settings (ex: resource prior probabilities, tranches, etc.) required to run the different VQSR steps are injected through pipeline parameters or hard coded in the vqsr modules. The values chosen for these settings are based on NIH [Biowulf](https://hpc.nih.gov/training/gatk_tutorial/vqsr.html) 

We aim to fully configure VQSR settings in the future and remove any hard-coded values, including reference data files. We are progressively adding configuration parameters for each VQSR process, but this work is not yet complete. If a parameter is not specified, it will default to the previous hard-coded value. To maintain harmonization, it is best NOT to specify the parameter or use a value equivalent to the default. Available configuration parameters involving VQSR reference data files are documented below.

#### vqsr_snp_resources parameter

> **⚠️ Warning: We recommend not setting this parameter for now until all VQSR processes are configurable.**

The `vqsr_snp_resources` parameter is used to specify the reference datasets for Variant Quality Score Recalibration (VQSR) for SNPs. VQSR is a machine learning-based approach that uses known, high-confidence variants to build a model of variant quality. This model is then applied to the variants in your dataset to assign quality scores, which can be used to filter out low-quality variants.

The `vqsr_snp_resources` parameter is a list of dictionaries, each containing the following keys:
- `labels`: A string specifying the labels for the resource. Refer to the [gatk VariantRecalibrator documentation](https://gatk.broadinstitute.org/hc/en-us/articles/360036510892-VariantRecalibrator#--resource) for a description of the expected format.
- `vcf`: The path to the VCF file containing the reference variants.
- `index`: The path to the index file for the VCF file.

Here is an example:

```
   vqsr_snp_resources = [
        [labels: "hapmap,known=false,training=true,truth=true,prior=15", vcf: "data-test/reference/broad/hapmap_3.3.hg38.vcf.gz", index: "data-test/reference/broad/hapmap_3.3.hg38.vcf.gz.tbi"],
        [labels: "omni,known=false,training=true,truth=false,prior=12", vcf: "data-test/reference/broad/1000G_omni2.5.hg38.vcf.gz", index: "data-test/reference/broad/1000G_omni2.5.hg38.vcf.gz.tbi"],
        [labels: "1000G,known=false,training=true,truth=false,prior=10", vcf: "data-test/reference/broad/1000G_phase1.snps.high_confidence.hg38.vcf.gz", index: "data-test/reference/broad/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi"],
        [labels: "dbsnp,known=true,training=false,truth=false,prior=7", vcf: "data-test/reference/broad/Homo_sapiens_assembly38.dbsnp138.vcf", index: "data-test/reference/broad/Homo_sapiens_assembly38.dbsnp138.vcf.idx"]
    ]
```

## Interval file 
The `intervalFile` parameter specifies the path to an interval file (ex: `broad/wgs_calling_regions.hg38.interval_list`).

If specified, the given interval file will be used to defines the genomic interval(s) over which we operate (WES, WGS or targeted sequencing).
For more details, see [Gatk documentation](https://gatk.broadinstitute.org/hc/en-us/articles/360035531852-Intervals-and-interval-lists).


## VEP Cache Directory
The `vep_cache` parameter specifies the directory for the vep cache. It is only required if `vep` is specified via the
`tools` parameter.

The vep cache is not automatically populated by the pipeline. It must be pre-downloaded. You can obtain a copy of the 
data by following the [vep installation procedure](https://github.com/Ensembl/ensembl-vep). Generally, we only need the human files obtainable from [Ensembl](https://ftp.ensembl.org/pub/release-111/variation/vep/homo_sapiens_vep_111_GRCh38.tar.gz).
Make sure to use the data release matching the vep version used (i.e. configured docker container for the vep process).

## Exomiser reference data
The exomiser reference data is only required if `exomiser` is specified via the `tools` parameter.

The `exomiser_data_dir` parameter specifies the path to the directory containing the exomiser reference files.
This directory will be passed to the exomiser tool via the exomiser option `--exomiser.data-directory`.

It's content should look like this:
```
2402_hg19/
2402_hg38/
2402_phenotype/
remm/
  ReMM.v0.3.1.post1.hg38.tsv.gz
  ReMM.v0.3.1.post1.hg38.tsv.gz.tbi
cadd/1.7/
  gnomad.genomes.r4.0.indel.tsv.gz
  gnomad.genomes.r4.0.indel.tsv.gz.tbi
  whole_genome_SNVs.tsv.gz
  whole_genome_SNVs.tsv.gz.tbi
```

- *2402_hg19/* and *2402_hg38/*: These folders contain data associated with the `hg19` and `hg38` genome assemblies, respectively. The number `2402` corresponds to the exomiser data version. 
- *remm/*: This folder is required only if REMM is used as a pathogenicity source in the exomiser analysis. In this case, additional parameters must be provided to specify the REMM data version (here `0.3.1.post1`) and the name of the .tsv.gz file to be used within this folder. See below.
- *cadd/*: This folder is required only if CADD is used as a pathogenicity source in the exomiser analysis. Here `1.7` is the CADD data version. As for REMM, additionnal parameters must be provided. See below.

To prepare the exomiser data directory, follow the instructions in the [exomiser installation documentation](https://exomiser.readthedocs.io/en/latest/installation.html#linux-install)

Exomiser allows the use of a custom file for frequency data sources, typically to reduce the priority of high-frequency variants caused by artifacts. To use this feature, specify the `LOCAL` frequency source in the exomiser analysis file. Then, provide the paths to your custom frequency file and its index using the parameters `exomiser_local_frequency_path` and `exomiser_local_frequency_index_path`. Note that the index file is required if using this feature.

Together with the `exomiser_data_dir` parameter, these parameters must be provided to exomiser and should match the reference data available
- `exomiser_genome`: The genome assembly version to be used by exomiser. Accepted values are `hg38` or `hg19`.
- `exomiser_data_version`: The exomiser data version. Example: `2402`.
- `exomiser_cadd_version`: The version of the CADD data to be used by exomiser (optional). Example: `1.7`. 
- `exomiser_cadd_indel_filename`: The filename of the exomiser CADD indel data file (optional). Example: `gnomad.genomes.r4.0.indel.tsv.gz` 
- `exomiser_cadd_snv_filename`: The filename of the exomiser CADD snv data file (optional). Example: `whole_genome_SNVs.tsv.gz`
- `exomiser_remm_version`: The version of the REMM data to be used by exomiser (optional). Example:`0.3.1.post1`
- `exomiser_remm_filename`: The filename of the exomiser REMM data file (optional). Example: `ReMM.v0.3.1.post1.hg38.tsv.gz`
- `exomiser_local_frequency_path`: Path to a custom frequency source file (optional).
- `exomiser_local_frequency_index_path`: Path to the index file (.tbi) of the custom frequency source file (optional).

## Exomiser analysis files
In addition to the reference data, exomiser requires an analysis file (.yml/.json) that contains, among others 
things, the variant frequency sources for prioritization of rare variants, variant pathogenicity sources to consider, the list of filters and prioritizers to apply, etc.

Typically, different analysis settings are used for whole exome sequencing (WES) and whole genome sequencing (WGS) data.
Defaults analysis files are provided for each sequencing type in the assets folder:
- assets/exomiser/default_exomiser_WES_analysis.yml
- assets/exomiser/default_exomiser_WGS_analysis.yml

You can override these defaults and provide your own analysis file(s) via parameters `exomiser_analyis_wes` and `exomiser_analysis_wgs`. 
Note that the default analysis files do not include REMM or CADD pathogenicity sources.

The exomiser analysis file format follows  the `phenopacket` standard and is described in detail [here](https://exomiser.readthedocs.io/en/latest/advanced_analysis.html#analysis). 
There are typically multiple sections in the analysis file. To be compatible with the way we run the exomiser command, your 
analysis file should contain only the `analysis` section.

## Reference data parameters summary

| Parameter name | Required? | Description |
| --- | --- | --- |
| `referenceGenome` |  _Required_ | Path to the directory containing the reference genome data |
| `referenceGenomeFasta` | _Required_ | Filename of the reference genome .fasta file, within the specified `referenceGenome` directory |
| `dbsnpFile` | _Optional_ | Path to dbsnp file. If specified, will be used to add ids in the ID column of output vcf files. |
| `dbsnpFileIndex` | _Optional_ | Path to dbsnp file index. Must be specified if the dbsnpFile parameter is specified. |
| `broad` | _Optional_ | Path to the directory containing Broad reference data (for VQSR) |
| `intervalsFile` | _Optional_ | Path to the file containg the genome intervals list on which to operate |
| `vepCache` | _Optional_ | Path to the vep cache data directory |
| `exomiser_data_dir` | _Optional_ | Path to the exomiser reference data directory |
| `exomiser_genome` | _Optional_ | Genome assembly version to be used by exomiser(`hg19` or `hg38`) |
| `exomiser_data_version` | _Optional_ | Exomiser data version (e.g., `2402`) |
| `exomiser_cadd_version` | _Optional_ | Version of the CADD data to be used by exomiser (e.g., `1.7`) |
| `exomiser_cadd_indel_filename`|	_Optional_ | Filename of the exomiser CADD indel data file (e.g., `gnomad.genomes.r4.0.indel.tsv.gz`) |
| `exomiser_cadd_snv_filename`|	_Optional_ | Filename of the exomiser CADD snv data file (e.g., `whole_genome_SNVs.tsv.gz`) |
| `exomiser_remm_version` | _Optional_ | Version of the REMM data to be used by exomiser (e.g., `0.3.1.post1`)|
| `exomiser_remm_filename` | _Optional_	| Filename of the exomiser REMM data file (e.g., `ReMM.v0.3.1.post1.hg38.tsv.gz`) |
| `exomiser_local_frequency_path`| _Optional_ | Path to a custom frequency source file |
| `exomiser_local_frequency_index_path`| _Optional_ | Path to the index file (.tbi) of the custom frequency source file. Required if specifying `exomiser_local_frequency_path`. |
| `exomiser_analysis_wes` | _Optional_ | Path to the exomiser analysis file for WES data, if different from the default |
| `exomiser_analysis_wgs` | _Optional_ | Path to the exomiser analysis file for WGS data, if different from the default |

