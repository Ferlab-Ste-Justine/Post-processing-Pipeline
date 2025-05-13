//
// Subworkflow with functionality specific to the ferlab/postprocessing pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'
include { isExomiserToolIncluded } from './utils'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )
    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    //_________Local___________

    //
    // Create channel from input file provided through params.input
    //
    if (params.step == 'genotype' && params.input) {
        log.info("Reading input samplesheet")
        Channel
            .fromSamplesheet("input")
            .map {
                meta, gvcf, _vcf, _tbi -> //note use vcf and tbi for now. TODO: implement starting from a different step given a custom samplesheet.
                [meta.familyId, [meta, gvcf]]
            }
            .tap{ch_sample_simple} //Save this channel to join later
            .groupTuple()
            .map{
                familyId, ch_items ->
                if(isExomiserToolIncluded()){
                    validatePhenopacketFiles(familyId, ch_items)
                }
                [familyId, ch_items.size()]
            }
            .combine(ch_sample_simple,by:0)
            .map {
                id,size,metasfile -> //include sample count in meta
                    def meta = metasfile[0]
                    [
                        meta + [sampleSize: size] + [id: meta.familyId + "." + meta.sample], //meta.id is referenced in modules
                        metasfile[1]                       //file
                    ]
            }.set {ch_samplesheet}
    } 
    else {
        input_restart = findIntermediateInput(params.step, outdir, params.exomiser_start_from_vep)

        Channel.fromPath(input_restart,checkIfExists: true)
            .splitCsv(header: true)
            .map { row -> 
                def meta = row.subMap('id','familyId', 'sequencingType')
                meta += ['familyPheno': row.familyPheno == 'null' ? [] : row.familyPheno ]
                def vcf = file(row.vcf, checkIfExists: true)
                def tbi = file(row.tbi, checkIfExists:true) ?: (file("${vcf}.tbi", checkIfExists:true) ?: null)
                if (!tbi) {
                    log.warn "No TBI file found for VCF: ${vcf}"
                    }
                [meta, vcf, tbi]
            }
            .set { ch_samplesheet }

    }



    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    command_line    //  string: Command line used to run the pipeline

    main:

    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion summary
    //
    workflow.onComplete {
        completionSummary(monochrome_logs)

        // Copy the nextflow log file to the pipeline info folder
        def log_file = getLogFile(command_line)
        def destination = getPipelineInfoFolder(outdir) + "/nextflow.log"
        log.info "Copying nextflow log file ${log_file} to ${destination}"
        file(log_file).copyTo(destination)
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/
//
//_____________Local functions_____________
//
// Extracts the nextflow log file path from the given command line string.
// If the '-log' option is present, it returns the specified log file path.
// Otherwise, it defaults to '.nextflow.log'.
 //
def getLogFile(command_line) {
    if (!command_line) {
        error "Command line not provided"
    }

    // Tokenize the command line while preserving quoted arguments as single tokens.
    // For example, the command line 'arg1 "arg2 with spaces"' will be parsed into two tokens: 'arg1' and 'arg2 with spaces'.
    def matcher = command_line =~ /"([^"]+)"|'([^']+)'|(\S+)/
    def tokens = []
    matcher.each { match ->
        tokens << (match[1] ?: match[2] ?: match[3])
    }

    def log_option_index = tokens.lastIndexOf("-log")
    return log_option_index >= 0 ? tokens[log_option_index + 1] : '.nextflow.log'
}

//
// Returns the path to the pipeline info folder within the specified output directory.
// We encourage you to reuse this function instead of hardcoding the path to ease maintenance in
// case the folder structure changes in the future.
//
def getPipelineInfoFolder(outdir) {
    if (!outdir) {
        error "Output directory not provided"
    }
    return "${outdir}/pipeline_info"
}

def validatePhenopacketFiles(family_id, metafiles) {
    def phenopacket_files =  metafiles.collect{it[0].familypheno}.unique(false)
    if(phenopacket_files.size() > 1){
        error("All samples in the same family must have the same familyPheno value in the input samplesheet. Found ${phenopacket_files} in family ${family_id}.")
    }
}

def findIntermediateInput(step, outdir, exomiser_start_from_vep) {
    if (step == "genotype") {
        error("Must provide samplesheet as input for genotype step.")
    } else if (step == "annotation") {
        error("Starting from annotation step with intermediate files is not yet supported.")
        // log.warn("Using intermediate file ${outdir}/csv/genotyped.csv as input for annotation step.")
        // return "${outdir}/csv/genotyped.csv"
    } else if (step == "exomiser") {
        if (exomiser_start_from_vep) {
            log.info("Using intermediate file ${outdir}/csv/ensemblvep.csv as input for exomiser step.")
            return "${outdir}/csv/ensemblvep.csv"
        } else {
            log.info("Using intermediate file ${outdir}/csv/genotyped.csv as input for exomiser step.")
            return "${outdir}/csv/genotyped.csv"
        }
    } else {
        error("Unknown step: ${step}")
    }
}

//_____________Template functions_____________
//
// Check and validate pipeline parameters
//
def validateInputParameters() {
    if (params.allow_old_gatk_data) {
        log.warn "The 'allow_old_gatk_data' parameter is set to true, allowing the pipeline to run with older GATK data in GATK4_GENOTYPEGVCFS. Not recommended for production."
    }
    if (params.step == 'exomiser' && !isExomiserToolIncluded()) {
        log.warn "Step is exomiser but Exomiser is not included in tools. Appending exomiser to tools list."
        params.tools = "exomiser," + params.tools
    }
    genomeExistsError()
}

//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[ params.genome ].containsKey(attribute)) {
            return params.genomes[ params.genome ][ attribute ]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available genome keys are:\n" +
            "  ${params.genomes.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}
