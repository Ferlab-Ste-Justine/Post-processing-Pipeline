/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//modules and subworkflows
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { EXCLUDE_MNPS           } from "../subworkflows/local/exclude_mnps"
include { VQSR                   } from "../subworkflows/local/vqsr"
include { EXOMISER                  } from '../modules/local/exomiser'
include { hardFiltering          } from '../modules/local/hardFilter'
include { splitMultiAllelics     } from '../modules/local/vep'
include { vep                    } from '../modules/local/vep'
include { tabix                  } from '../modules/local/vep'
include { COMBINEGVCFS           } from '../modules/local/combine_gvcfs'
include { GATK4_GENOTYPEGVCFS     } from '../modules/nf-core/gatk4/genotypegvcfs'

//functions
include { isExomiserToolIncluded } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'
include { isVepToolIncluded } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*
/**
Tag variants that are probable artifacts

In the case of whole genome sequencing data, we use the vqsr procedure.
For whole exome sequencing data, since the vqsr procedure is not supported, we use
a hard filtering approach.
*/
def tagArtifacts(inputChannel, hardFilters) {
    def wgs = inputChannel.filter{it[0].sequencingType == "WGS"}
    def wes = inputChannel.filter{it[0].sequencingType == "WES"}
    def wgs_filtered = VQSR(wgs)
    def wes_filtered = hardFiltering(wes, hardFilters)

    return wgs_filtered.concat(wes_filtered)
}

def exomiser(inputChannel, 
    exomiser_genome,
    exomiser_data_version,
    exomiser_data_dir, 
    analysis_wes_path, 
    analysis_wgs_path,
    remm_version,
    remm_filename,
    cadd_version,
    cadd_snv_filename,
    cadd_indel_filename
    ) {
    def ch_input_for_exomiser = inputChannel.map{meta, files -> [
        meta,
        files,
        meta.familypheno, 
        meta.sequencingType == "WES"? file(analysis_wes_path) : file(analysis_wgs_path)
    ]}
    def remm_input = ["", ""]
    if (remm_version) {
        remm_input = [remm_version, remm_filename]
    }
    def cadd_input = ["", "", ""]
    if (cadd_version) {
        cadd_input = [cadd_version, cadd_snv_filename, cadd_indel_filename]
    }
    EXOMISER(ch_input_for_exomiser,
        file(exomiser_data_dir),
        exomiser_genome,
        exomiser_data_version,
        remm_input,
        cadd_input
    )  
}

process writemeta{

    publishDir "${params.outdir}/pipeline_info/", mode: 'copy', overwrite: 'true'
    output:
    path("metadata.txt")

    script:
    """
    cat <<EOF > metadata.txt
    Work Dir : ${workflow.workDir}
    UserName : ${workflow.userName}
    ConfigFiles : ${workflow.configFiles}
    Container : ${workflow.container}
    Start date : ${workflow.start}
    Command Line : ${workflow.commandLine}
    Revision : ${workflow.revision}
    CommitId : ${workflow.commitId}
    """
}


workflow POSTPROCESSING {
    //Local Temp Params
    def referenceGenome = file(params.referenceGenome)
    def pathReferenceGenomeFasta = file(params.referenceGenome + "/" + params.referenceGenomeFasta)
    def pathReferenceGenomeFai = file(pathReferenceGenomeFasta + ".fai")
    def broad = file(params.broad)
    def pathIntervalFile = file(params.broad + "/" + params.intervalsFile)
    def pathReferenceDict = file(params.referenceGenome + "/" + params.referenceGenomeFasta.substring(0,params.referenceGenomeFasta.indexOf(".")) + ".dict")
    file(params.outdir).mkdirs()

    take:
    ch_samplesheet

    main:

    ch_versions = Channel.empty()

    Channel
    .fromList(workflow.configFiles)
    .collectFile(storeDir: "${params.outdir}/pipeline_info/configs",cache: false)

    writemeta()
    def ch_output_from_excludemnps = EXCLUDE_MNPS(ch_samplesheet).ch_output_excludemnps
    //Create groupkey for the grouptuple and separate the vcf (file[0]) and the index (files[1])
        .map{meta, files -> tuple(groupKey(meta.familyId, meta.sampleSize),meta,files[0],files[1])}
        .groupTuple()
        .map{ familyId, meta, vcf, tbi -> 
        //now that samples are grouped together, we no longer follow sample in meta, and the id no longer needs the sampleId
            def updated_meta = meta[0].findAll{!["sample", "id"].contains(it.key) }
            updated_meta["id"] = updated_meta.familyId
            [updated_meta, vcf.flatten(), tbi.flatten()]}
    


    //Combine per-sample gVCF files into a multi-sample gVCF file
    def filtered_one = ch_output_from_excludemnps.filter{it[0].sampleSize == 1}
    def ch_input_for_combinegvcf = ch_output_from_excludemnps.filter{it[0].sampleSize > 1}    
    def ch_output_from_combinegvcf = COMBINEGVCFS(ch_input_for_combinegvcf , pathReferenceGenomeFasta,pathReferenceGenomeFai,pathReferenceDict,pathIntervalFile).combined_gvcf
    .join(COMBINEGVCFS.out.tbi)
    .concat(filtered_one)

    //Perform joint genotyping on one or more samples  
    def ch_input_for_genotypegvcf = ch_output_from_combinegvcf.map{meta,vcf,tbi -> [meta,vcf,tbi, [], []]}
    def ch_output_from_genotypegvcf = GATK4_GENOTYPEGVCFS(
    ch_input_for_genotypegvcf,
    [[:], pathReferenceGenomeFasta],
    [[:], pathReferenceGenomeFai],
    [[:], pathReferenceDict],
    [[:], []], //leaving empty as we don't use dbsnp
    [[:], []]  //leaving empty as we don't use dbsnp
    ).vcf
    .join(GATK4_GENOTYPEGVCFS.out.tbi)
    .map{ meta, vcf, tbi -> [meta, [vcf,tbi]]}

    //tag variants that are probable artifacts
    def ch_output_from_tagArtifacts = tagArtifacts(ch_output_from_genotypegvcf, params.hardFilters)
    //tag frequent mutations in the population
    def ch_output_from_splitMultiAllelics = splitMultiAllelics(ch_output_from_tagArtifacts, referenceGenome)

    //Annotating mutations
    if (isVepToolIncluded()) {
        def vepCache = file(params.vepCache)

        vep(ch_output_from_splitMultiAllelics, referenceGenome, vepCache)
        tabix(vep.out)
    }

    if (isExomiserToolIncluded()) {
        exomiser(ch_output_from_splitMultiAllelics, 
            params.exomiser_genome,
            params.exomiser_data_version,
            params.exomiser_data_dir,
            params.exomiser_analysis_wes,
            params.exomiser_analysis_wgs,
            params.exomiser_remm_version,
            params.exomiser_remm_filename,
            params.exomiser_cadd_version,
            params.exomiser_cadd_snv_filename,
            params.exomiser_cadd_indel_filename
        )
    }

    emit:
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
