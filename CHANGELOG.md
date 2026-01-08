# ferlab/Post-Processing-Pipeline: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased 

### `Added`
- [#82](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/82) Updated CODEOWNERS to add new maintainers.

## v2.10.0 - 2026-01-08

### `Added`
- [#80](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/80) Added param --cache_species to allow the download of different cache types.

### `Changed`
- [#79](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/79) Updated CI workflow to include new test data from S3.

## v2.9.1 - 2025-11-13
### `Fixed`
- [#78](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/78) Fixed bug preventing exomiser to execute when starting from annotation step.

## v2.9.0 - 2025-06-12

### `Added`
- [#76](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/76) Allow to start/re-start pipeline from defined intermediate steps. Creates csv files of published results. 

### `Changed`
- [#76](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/76) Changed meta field familypheno to familyPheno.

### `Removed`
- [#75](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/75) Remove the nextflow docker image
  
## v2.8.1 - 2025-04-11 
### `Changed`
- [#73](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/73) Pass intervals file to GenotypeGVCFs if available.

## v2.8.0 - <small>2025-04-03</small>

### `Added`
- [#71](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/71) Add parameters exomiser_outdir and vep_outdir to allow separate publish folders for exomiser and vep

### `Changed`
- [#71](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/71) Replaces the exomiser/results output folder with exomiser
- [#71](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/71) Only publish the output of the splitmultiallelics process when publish_all parameter is set to true

### `Fixed`
- [#68](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/68) Corrected documentation for the exclude_mnps parameter and familyPheno samplesheet column

## v2.7.0 - <small>2025-03-26</small>

### `Added`

- [#66](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/66) Allow to configure the first step of VQSR SNP variant recalibration (model building) via parameters

### `Fixed`
- [#69](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/69) Accept .vcf and .vcf.gz file extensions for input gvcf files

## v2.6.0 - <small>2025-02-07</small>

### `Added`

- [#63](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/63) Allow to skip exomiser for specific families

## v2.5.0 - <small>2025-01-30</small>

### `Added`
- [#61](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/61) Add download VEP module form nf-core. Addresses [#BIOINFO-20](https://ferlab-crsj.atlassian.net/browse/BIOINFO-20), no cache version issues were found.

### `Changed`
- [#59](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/59) Add ".snv" to VEP output filename prefix
  
### `Deprecated`
- Changelog versioning format vx.y.z-dev is deprecated as of now. We will now keep an [Unreleased section](#unreleased) at the top to track upcoming changes. When bumping the version, move the Unreleased section changes under the new version section. Listed changes will now be associated with the specific tag.

## v2.4.1-dev - <small>2025-01-16</small>

## v2.4.0-dev

### `Fixed`
- [#57](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/57) Allow to pass exomiser application properties

## v2.3.0-dev

### `Added`
- [#44](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/44) Make interval file optional in GenotypeGVCFs process
- [#44](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/44) Decouple the interval file parameter from the broad
- [#45](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/45) Allow to add dbsnp ids to output vcf files
- [#46](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/46) Allow to skip the exclude mnp step
- [#47](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/47) Improve pipeline output documentation
- [#48](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/48) Publish only main outputs by default
- [#49](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/49) Add support for local frequency source
- [#49](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/49) Pass java -Xmx option at the command line for exomiser
- [#53](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/53) Replace vep and tabix logic by a standard nf-core subworkflow
- [#54](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/54) Allow exomiser to start from the vep output

### `Changed`
- [#54](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/54) Standardize exomiser output filenames

### `Fixed`
- [#50](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/50) Use container tag 1.20 for splitMultiAllelics process
- [#51](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/51) Add missing ressources for exomiser process in configuration
- [#52](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/52) Ensure .gvcf file extensions are supported in all scenarios

### `Known issues`
- The nf-core modules that we are using have a potential performance flaw. Typically, the regex used to describe the output files also match the input files (ex: "*.vcf"), which can cause unnecessary file transfers.  This has already proven to cause issues on fusion. One fix could be to transfer the whole modules to local to perform the small change necessary to fix this.
- The VEP cache version used in the CQDG environment (112) does not match the default configured VEP version (111). This issue can be avoided by overriding the Docker container of the ensemblevep process. If no project is using VEP version 111, it should not be used as the default value.


## v2.2.0-dev

### `Added`
- [#41](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/41) Allow to customize the vep command
- [#41](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/41) Improve parameter schema for params max_disk, max_memory, max_time
- [#41](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/41) Consider only stable nextflow versions for ci test
- [#42](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/42) Add docker image for exomiser 13.1.0

### `Known issues`
- The nf-core modules that we are using have a potential performance flaw. Typically, the regex used to describe the output files also match the input files (ex: "*.vcf"), which can cause unnecessary file transfers.  This has already proven to cause issues on fusion. One fix could be to transfer the whole modules to local to perform the small change necessary to fix this.
- The VEP cache version used in the CQDG environment (112) does not match the default configured VEP version (111). This issue can be avoided by overriding the Docker container of the ensemblevep process. If no project is using VEP version 111, it should not be used as the default value.

### `Fixed`
- [#41](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/41) Fix vep url pointing to the wrong vep version in the reference data documentation.


## v2.1.0dev

### `Added`
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Added allow_old_gatk_data parameter (set to false by default).
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Added missing stub block in process writemeta for compatibility with latest nextflow version.
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Improve github ci workflow to display nextflow log file content on error

### `Fixed`
- [#35](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/35) Fix incorrect assumption about assets folder location in github ci workflow
- [#36](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/36) Fix variable input in process BCFTOOLS_NORM causing resume problems

### `Known issues`
- The nf-core modules genotypeGVCFs and VARIANTFILTRATION have a potential performance flaw. The output glob specifies for vcf and tbi *.vcf and *.vcf.tbi respectively. This regex will also include the inputs, which can cause unnecessary file transfers. This has already proven to cause issues on fusion. One fix could be to transfer the whole modules to local to perform the small change necessary to fix this (change the globs to *${prefix}.vcf)


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
