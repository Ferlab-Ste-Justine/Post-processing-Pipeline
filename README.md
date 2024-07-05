[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/ferlab/postprocessing)

## Introduction

**ferlab/postprocessing** is a bioinformatics pipeline that recombines gvcf for family's samples in order to facilitate denovo identification.

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->
###  Summary:
1. Remove MNPs from bedtools 
2. Combine gvcfs
3. [Joint-genotyping](https://gatk.broadinstitute.org/hc/en-us/articles/360037057852-GenotypeGVCFs)
4. Remove false positives with either:
  - If using whole genome sequencing: [Variant quality score recalibration (VQSR)](https://gatk.broadinstitute.org/hc/en-us/articles/360036510892-VariantRecalibrator)
  - If using whole exome sequencing: [Hard-Filtering](https://gatk.broadinstitute.org/hc/en-us/articles/360036733451-VariantFiltration)
5. Annotate variants with [Variant effect predictor (VEP)](https://useast.ensembl.org/info/docs/tools/vep/index.html)


## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

### Samples
The workflow will accept sample data in two format (called V1 and V2). The path to the sample file must be specified with the "**sampleFile**" parameter.

1.  The first format is used by default and looks as follows:

**sampleV1.tsv**

_FAMILY_ID_ &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; _Patient1_File_&nbsp; &nbsp; &nbsp;&nbsp; &nbsp;_Patient2_File_&nbsp; &nbsp; &nbsp; &nbsp;&nbsp;_Patient3_File_
```tsv
CONGE-XXX       CONGE-XXX-01.hard-filtered.gvcf.gz   CONGE-XXX-02.hard-filtered.gvcf.gz   CONGE-XXX-03.hard-filtered.gvcf.gz
CONGE-YYY       CONGE-YYY-01.hard-filtered.gvcf.gz   CONGE-YYY-02.hard-filtered.gvcf.gz   CONGE-YYY-03.hard-filtered.gvcf.gz
```

2.  The second format is used in older data and includes the sequencing type (WGS or WES)

**sampleV2.tsv**

_FAMILY_ID_ &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; _SEQUENCING_TYPE_ &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;_Patient1_File_&nbsp; &nbsp; &nbsp;&nbsp; &nbsp;_Patient2_File_&nbsp; &nbsp; &nbsp; &nbsp;&nbsp;_Patient3_File_
```tsv
CONGE-XXX       WES       CONGE-XXX-01.hard-filtered.gvcf.gz   CONGE-XXX-02.hard-filtered.gvcf.gz   CONGE-XXX-03.hard-filtered.gvcf.gz
CONGE-YYY       WES       CONGE-YYY-01.hard-filtered.gvcf.gz   CONGE-YYY-02.hard-filtered.gvcf.gz   CONGE-YYY-03.hard-filtered.gvcf.gz
```


The file format can be chosen with the "**sampleFileFormat**" parameter (either "V1" or "V2", default "V1"). Note that both types are tab-delimited (.tsv)

Next, if the file format is "V1", the sequencing type can be specified with the "**sequencingType**" parameter (either "WGS" for Whole Genome Sequencing or "WES" for Whole Exome Sequencing, default "WGS")

> [!NOTE]
> The sequencing type also determines the type of variant filtering the pipeline will use.
> 
> In the case of Whole Genome Sequencing, VQSR (Variant Quality Score Recalibration) is used (preferred method).
> 
> In the case of Whole Exome Sequencing, Hard-filtering needs to be used.

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run ferlab/postprocessing \
   -profile <docker/singularity/.../> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

### References
Reference files are necessary at multiple steps of the workflow, notably for joint-genotyping,the variant effect predictor (VEP) and VQSR. 

Specifically, we need a reference genome directory and filename specified with the **referenceGenome** and **referenceGenomeFasta** parameters respectively. 

Generally, we use the Homo_sapiens_assembly38.fasta as referenceGenome (see Resources)



Next, we also need broader references, which are contained in a path defined by the **broad** parameter.

The broad directory must contain the following files:

- The interval list which determines the genomic interval(s) over which we operate: filename of this list must be defined with the **intervalsFile** parameter
- Highly validated variance ressources currently required by VQSR. ***These are currently hard coded in the pipeline!***
  - HapMap file : hapmap_3.3.hg38.vcf.gz
  - 1000G omni2.5 file : 1000G_omni2.5.hg38.vcf.gz
  - 1000G reference file : 1000G_phase1.snps.high_confidence.hg38.vcf.gz
  - SNP database : Homo_sapiens_assembly38.dbsnp138.vcf.gz

 
Finally, the vep cache directory must be specified with **vepCache**, which is usually created by vep itself on first installation.
Generally, we only need the human files obtainable from https://ftp.ensembl.org/pub/release-112/variation/vep/homo_sapiens_vep_112_GRCh38.tar.gz

### Stub run
The -stub-run option can be added to run the "stub" block of processes instead of the "script" block. This can be helpful for testing.

🚧

Parameters summary
-----

| Parameter name | Required? | Accepted input |
| --- | --- | --- |
| `sampleFile` | _Required_ | file |
| `sampleFileFormat` | _Optional_ | `V1` or `V2`, default `V1` |
| `sequencingType` | _Optional_ | `WGS` or `WES`, default `WGS` |
| `referenceGenome` | _Required_ | path |
| `referenceGenomeFasta` | _Required_ | file |
| `broad` | _Required_ | path |
| `intervalsFile` | _Required_ | list of genome intervals |
| `vepCache` | _Required_ | path |

## Credits

ferlab/postprocessing was originally written by Damien Geneste, David Morais, Felix-Antoine Le Sieur, Jeremy Costanza, Lysiane Bouchard.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

Resources
-----
The documentation of the various tools used in this workflow are available here:

[Nextflow](https://www.nextflow.io/docs/latest/index.html)

[bcftools](https://samtools.github.io/bcftools/bcftools.html)

**GATK**:
- [CombineGVCFs](https://gatk.broadinstitute.org/hc/en-us/articles/360037593911-CombineGVCFs)
- [GenotypeGVCFs](https://gatk.broadinstitute.org/hc/en-us/articles/360037057852-GenotypeGVCFs)
- [VariantRecalibrator](https://gatk.broadinstitute.org/hc/en-us/articles/360035531612-Variant-Quality-Score-Recalibration-VQSR)
- [VariantFiltration](https://gatk.broadinstitute.org/hc/enus/articles/360041850471-VariantFiltration))

[VEP](https://useast.ensembl.org/info/docs/tools/vep/script/vep_options.html)

## Citations

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
