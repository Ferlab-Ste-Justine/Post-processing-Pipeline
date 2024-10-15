# ferlab/postprocessing: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.1.0dev - [date]

### `Added`
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Added allow_old_gatk_data parameter (set to false by default).
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Added missing stub block in process writemeta for compatibility with latest nextflow version.
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Improve github ci workflow to display nextflow log file content on error

### `Fixed`
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Fix incorrect assumption about assets folder location in github ci workflow
- [#36](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/36) Fix variable input in process BCFTOOLS_NORM causing resume problems

## v2.0.0dev

### `Added`
- [#25](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/25) Added exomiser module and introduced `tools` parameter to control the execution of VEP and Exomiser.
- [#25](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/25) Group vep output files in subfolder `vep`.
- [#26](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/26) Add version file in exomiser docker image
- [#27](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/27) Added nf-core module GATK4_VARIANTFILTRATION to replace local module hardFilters.nf

### `Known issues`
- [#20](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/20) [#27](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/27) The nf-core modules genotypeGVCFs and VARIANTFILTRATION have a potential performance flaw. The output glob specifies for vcf and tbi *.vcf and *.vcf.tbi respectively. This regex will also include the inputs, which can cause unnecessary file transfers. This has already proven to cause issues on fusion. One fix could be to transfer the whole modules to local to perform the small change necessary to fix this (change the globs to *${prefix}.vcf)


## v1.0dev

Initial release of ferlab/postprocessing, created with the [nf-core](https://nf-co.re/) template.

### `Added`
- [#2](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/2) Added tests and samplefile channel functions
- [#3](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/3) Added a test file for the test profile
- [#7](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/7) Added most functions and modules from previous pipeline to make it functional
- [#9](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/9) New format "V3" is now supported. Includes metadata propagation. 
- [#10](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/10) Converted the exclude_MNPs function into a nf-core subworkflow containing 2 nf-core modules. Also added test profile test data (but it fails at VQSR for now)
- [#17](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/17) Save nextflow log file to output directory on workflow completion
- [#17](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/17) Allow to run nf-tests check in github workflow
- [#19](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/19) Added local module COMBINEGVCFS to replace local function importGVCFs, mostly equivalent to nf-core module GATK4_COMBINEGVCFS
- [#20](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/20) Added nf-core module GATK4_GENOTYPEGVCFS to replace local function genotype_gvcf
- [#21](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/21) Added nextflow docker image
- [#22](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/22) Added exomiser docker image


### `Fixed`
- [#1](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/1) Fixed template schemas
- [#13](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/13) Run test in stub mode in GitLab workflow with necessary adjustments
- [#13](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/13) Add missing docker image for process writemeta
- [#13](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/13) Fix bug with extra java arguments in process genotypeGVCF

### `Dependencies`
- [#17](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/17) Updated nf-core subworkflows utils_nextflow_pipeline and utils_nfcore_pipeline

### `Deprecated`
- Format "V1" and "V2" are now deprecated as of [#9](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/9)

### `Removed`
- [#1](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/1) Removed input_schema
- [#2](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/2) Removed V1 format input. V2 is the only accepted format.
- [#5](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/5) Removed many files related to workflows and email notifications
- [#8](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/8) Removed remaining unnecessary workflows including the linting fix, the branch protection workflow and the "download pipeline" workflow
- [#13](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/13) Removed linter tests on gitHub workflows to customize them to our needs.
