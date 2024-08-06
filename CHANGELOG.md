# ferlab/postprocessing: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0dev - [date]

Initial release of ferlab/postprocessing, created with the [nf-core](https://nf-co.re/) template.

### `Added`
[#2](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/2) Added tests and samplefile channel functions
[#3](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/3) Added a test file for the test profile
[#7](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/7) Added most functions and modules from previous pipeline to make it functional
[#9](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/9) New format "V3" is now supported. Includes metadata propagation. 

### `Fixed`
[#1](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/1) Fixed template schemas

### `Dependencies`

### `Deprecated`
Format "V1" and "V2" are now deprecated as of [#9](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/9)
### `Removed`
[#1](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/1) Removed input_schema
[#2](https://github.com/FelixAntoineLeSieur/Post-processing-Pipeline/pull/2) Removed V1 format input. V2 is the only accepted format.
[#5](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/5) Removed many files related to workflows and email notifications
[#8](https://github.com/Ferlab-Ste-Justine/Post-processing-Pipeline/pull/8) Removed remaining unnecessary workflows including the linting fix, the branch protection workflow and the "download pipeline" workflow
