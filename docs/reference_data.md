# Ferlab-Ste-Justine/Post-processing-Pipeline: Reference Data

Reference files are essential at various steps of the pipeline, including joint-genotyping, VQSR, the Variant Effect Predictor (VEP), slivar, and exomiser. 

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

By default the broad directory is expected to contain the following files (each with its tabix `.tbi` index, except dbsnp which ships with `.idx`):

SNP recalibration:
  - HapMap : `hapmap_3.3.hg38.vcf.gz` (+ `.tbi`)
  - 1000G omni2.5 : `1000G_omni2.5.hg38.vcf.gz` (+ `.tbi`)
  - 1000G high-confidence SNPs : `1000G_phase1.snps.high_confidence.hg38.vcf.gz` (+ `.tbi`)
  - dbSNP : `Homo_sapiens_assembly38.dbsnp138.vcf` (+ `.idx`)

INDEL recalibration:
  - Mills + 1000G gold-standard indels : `Mills_and_1000G_gold_standard.indels.hg38.vcf.gz` (+ `.tbi`)
  - Axiom Exome Plus : `Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz` (+ `.tbi`)
  - dbSNP : `Homo_sapiens_assembly38.dbsnp138.vcf` (+ `.idx`) — re-used from the SNP set

These are the standard GATK best-practices VQSR training resources. The file names and prior probabilities are configurable via `vqsr_snp_resources` and `vqsr_indel_resources` (see below) — only the defaults assume the bundle filenames above. Extra settings (tranches, annotations, max-gaussians, mode, etc.) are configured through the `vqsr_*_tranches` / `vqsr_*_annotations` parameters; the defaults are based on NIH [Biowulf](https://hpc.nih.gov/training/gatk_tutorial/vqsr.html).

#### vqsr_snp_resources / vqsr_indel_resources

`vqsr_snp_resources` and `vqsr_indel_resources` specify the reference datasets used by GATK `VariantRecalibrator` to build the SNP and INDEL recalibration models, respectively. VQSR is a machine-learning approach that uses known high-confidence variants to score variant quality.

Each entry is a map with these keys:
- `labels`: the GATK `--resource:` label string (`<name>,known=...,training=...,truth=...,prior=N`). See [GATK VariantRecalibrator documentation](https://gatk.broadinstitute.org/hc/en-us/articles/360036510892-VariantRecalibrator#--resource).
- `vcf`: path to the training VCF (relative paths are joined with `params.broad`).
- `index`: path to the tabix/idx file for that VCF (also relative-to-`broad`).

The defaults in `nextflow.config` are the standard GATK best-practices bundle filenames; if your reference data lives in a directory other than `params.broad`, override the lists with absolute paths.

Example:

```groovy
vqsr_snp_resources = [
    [labels: "hapmap,known=false,training=true,truth=true,prior=15",  vcf: "hapmap_3.3.hg38.vcf.gz",                       index: "hapmap_3.3.hg38.vcf.gz.tbi"],
    [labels: "omni,known=false,training=true,truth=false,prior=12",   vcf: "1000G_omni2.5.hg38.vcf.gz",                    index: "1000G_omni2.5.hg38.vcf.gz.tbi"],
    [labels: "1000G,known=false,training=true,truth=false,prior=10",  vcf: "1000G_phase1.snps.high_confidence.hg38.vcf.gz",index: "1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi"],
    [labels: "dbsnp,known=true,training=false,truth=false,prior=7",   vcf: "Homo_sapiens_assembly38.dbsnp138.vcf",         index: "Homo_sapiens_assembly38.dbsnp138.vcf.idx"]
]

vqsr_indel_resources = [
    [labels: "mills,known=false,training=true,truth=true,prior=12",      vcf: "Mills_and_1000G_gold_standard.indels.hg38.vcf.gz",            index: "Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi"],
    [labels: "axiomPoly,known=false,training=true,truth=false,prior=10", vcf: "Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz", index: "Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz.tbi"],
    [labels: "dbsnp,known=true,training=false,truth=false,prior=2",      vcf: "Homo_sapiens_assembly38.dbsnp138.vcf",                        index: "Homo_sapiens_assembly38.dbsnp138.vcf.idx"]
]
```

Tranches and annotations are tunable via `vqsr_snp_tranches`, `vqsr_snp_annotations`, `vqsr_indel_tranches`, `vqsr_indel_annotations`. `--mode`, `--max-gaussians` and `--truth-sensitivity-filter-level` (the latter controlled by `TSfilterSNP` / `TSfilterINDEL`) live in `conf/modules.config`.

## Interval file 
The `intervalFile` parameter specifies the path to an interval file (ex: `broad/wgs_calling_regions.hg38.interval_list`).

If specified, the given interval file will be used to defines the genomic interval(s) over which we operate (WES, WGS or targeted sequencing).
For more details, see [Gatk documentation](https://gatk.broadinstitute.org/hc/en-us/articles/360035531852-Intervals-and-interval-lists).


## VEP Cache Directory

VEP requires a species- and version-specific cache directory. The pipeline supports two modes:

**1. Use an existing cache** (default): set `vep_cache` to the directory containing the pre-downloaded cache. The cache layout must match what VEP expects — typically `<vep_cache>/<species>/<vep_cache_version>_<vep_genome>/`. Required parameters:

- `vep_cache` — path to the cache root directory.
- `vep_cache_version` — VEP cache version (e.g. `111`). Must match the version baked into the VEP container (currently `release_111.0`).
- `vep_genome` — genome assembly (e.g. `GRCh38`).

To obtain a cache manually, follow the [VEP installation procedure](https://github.com/Ensembl/ensembl-vep). For human data, the relevant tarballs live at e.g. [ftp.ensembl.org](https://ftp.ensembl.org/pub/release-111/variation/vep/homo_sapiens_vep_111_GRCh38.tar.gz). Always match the cache release to the VEP container version.

**2. Download the cache from Ensembl on the fly**: set `--download_cache` to `true`. The pipeline runs the `ENSEMBLVEP_DOWNLOAD` step before VEP, which fetches the cache for the species/version/genome specified by `download_cache_species` (default `homo_sapiens`), `vep_cache_version`, and `vep_genome`. The downloaded cache is written to `outdir_cache` if set; otherwise to `${outdir}/cache/`. When `--download_cache` is enabled the locally downloaded cache is used regardless of any `vep_cache` value.

The container used for downloading is a conda-based VEP image (`quay.io/biocontainers/ensembl-vep:111.0--pl5321h2a3209d_0`).

## Slivar reference data

The slivar inheritance step uses [gnotate](https://github.com/brentp/slivar#gnotation-files) zip files to annotate variants with population-frequency information (gnomAD popmax allele frequency, gnomAD homozygous-alt count, TOPMed allele frequency). These annotations drive the rare-variant and inheritance filters applied by `slivar expr`.

Gnotate files are optional. If a gnotate file is omitted, the corresponding population-frequency guards are dropped from the slivar expressions automatically — the inheritance segregation logic still runs, but is no longer rarity-filtered against that population.

### gnomAD gnotate file
The `slivar_gnomad_gnotate` parameter specifies the path to a gnomAD-based slivar gnotate `.zip` file. When provided, the slivar expressions add `INFO.gnomad_popmax_af` and `INFO.gnomad_nhomalt` guards (tunable via the `gnomad_popmax_af_*` and `gnomad_nhomalt` parameters — see [usage.md](usage.md#slivar-inheritance-thresholds)).

Pre-built file for hg38 (gnomAD genomes v3): https://slivar.s3.amazonaws.com/gnomad.hg38.genomes.v3.fix.zip

For other assemblies or to build your own, see the [slivar gnotation files documentation](https://github.com/brentp/slivar#gnotation-files).

### TOPMed gnotate file
The `slivar_topmed_gnotate` parameter specifies the path to a TOPMed-based slivar gnotate `.zip` file. When provided, the general `--info` filter additionally enforces `INFO.topmed_af < topmed_af_rare`.

See the [slivar gnotation files documentation](https://github.com/brentp/slivar#gnotation-files) for details on building or obtaining a TOPMed gnotate file.

### Optional BED files
- `slivar_regions_bed`: BED file restricting analysis to the specified regions (passed to `slivar expr --regions`).
- `slivar_exclude_bed`: BED file of regions to exclude from analysis, e.g. low-complexity or blacklist regions (passed to `slivar expr --exclude`).

### Slivar JavaScript helpers
The `slivar_js` parameter points to a JavaScript file defining helper functions used in the slivar expressions (segregation, quality checks, etc.). It defaults to the bundled `assets/slivar-functions.js` and only needs to be overridden when using customized helper functions.

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

Exomiser allows the use of a custom file for frequency data sources, typically to reduce the priority of high-frequency variants caused by artifacts. To use this feature, specify the `LOCAL` frequency source in the exomiser analysis file. Then, provide the path to your custom frequency file via `exomiser_local_frequency_path`. The tabix index is assumed to live alongside the file at `<path>.tbi` — if your index is somewhere else, override it via `exomiser_local_frequency_index_path`.

Together with the `exomiser_data_dir` parameter, these parameters must be provided to exomiser and should match the reference data available
- `exomiser_genome`: The genome assembly version to be used by exomiser. Accepted values are `hg38` or `hg19`.
- `exomiser_data_version`: The exomiser data version. Example: `2402`.
- `exomiser_cadd_version`: The version of the CADD data to be used by exomiser (optional). Example: `1.7`. 
- `exomiser_cadd_indel_filename`: The filename of the exomiser CADD indel data file (optional). Example: `gnomad.genomes.r4.0.indel.tsv.gz` 
- `exomiser_cadd_snv_filename`: The filename of the exomiser CADD snv data file (optional). Example: `whole_genome_SNVs.tsv.gz`
- `exomiser_remm_version`: The version of the REMM data to be used by exomiser (optional). Example:`0.3.1.post1`
- `exomiser_remm_filename`: The filename of the exomiser REMM data file (optional). Example: `ReMM.v0.3.1.post1.hg38.tsv.gz`
- `exomiser_local_frequency_path`: Path to a custom frequency source file (optional).
- `exomiser_local_frequency_index_path`: Optional override for the tabix index of the local frequency file. Defaults to `<exomiser_local_frequency_path>.tbi`.

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
| `vqsr_snp_resources` | _Optional_ | List of `{labels, vcf, index}` maps describing the SNP VQSR training resources. Relative vcf/index paths are resolved against `params.broad`. |
| `vqsr_indel_resources` | _Optional_ | Same shape as `vqsr_snp_resources`, used for the INDEL VQSR model. |
| `intervalsFile` | _Optional_ | Path to the file containg the genome intervals list on which to operate |
| `vepCache` | _Optional_ | Path to the vep cache data directory |
| `slivar_gnomad_gnotate` | _Optional_ | Path to the gnomAD slivar gnotate (`.zip`) file. Required to apply gnomAD-based population-frequency guards in the inheritance expressions. |
| `slivar_topmed_gnotate` | _Optional_ | Path to the TOPMed slivar gnotate (`.zip`) file. Required to apply the TOPMed-based population-frequency guard. |
| `slivar_regions_bed` | _Optional_ | BED file restricting slivar analysis to the specified regions. |
| `slivar_exclude_bed` | _Optional_ | BED file of regions to exclude from slivar analysis. |
| `slivar_js` | _Optional_ | JavaScript file defining helper functions used in the slivar expressions. Defaults to `assets/slivar-functions.js`. |
| `exomiser_data_dir` | _Optional_ | Path to the exomiser reference data directory |
| `exomiser_genome` | _Optional_ | Genome assembly version to be used by exomiser(`hg19` or `hg38`) |
| `exomiser_data_version` | _Optional_ | Exomiser data version (e.g., `2402`) |
| `exomiser_cadd_version` | _Optional_ | Version of the CADD data to be used by exomiser (e.g., `1.7`) |
| `exomiser_cadd_indel_filename`|	_Optional_ | Filename of the exomiser CADD indel data file (e.g., `gnomad.genomes.r4.0.indel.tsv.gz`) |
| `exomiser_cadd_snv_filename`|	_Optional_ | Filename of the exomiser CADD snv data file (e.g., `whole_genome_SNVs.tsv.gz`) |
| `exomiser_remm_version` | _Optional_ | Version of the REMM data to be used by exomiser (e.g., `0.3.1.post1`)|
| `exomiser_remm_filename` | _Optional_	| Filename of the exomiser REMM data file (e.g., `ReMM.v0.3.1.post1.hg38.tsv.gz`) |
| `exomiser_local_frequency_path`| _Optional_ | Path to a custom frequency source file |
| `exomiser_local_frequency_index_path`| _Optional_ | Path to the tabix index of the local frequency file. Defaults to `<exomiser_local_frequency_path>.tbi` when omitted. |
| `exomiser_analysis_wes` | _Optional_ | Path to the exomiser analysis file for WES data, if different from the default |
| `exomiser_analysis_wgs` | _Optional_ | Path to the exomiser analysis file for WGS data, if different from the default |

