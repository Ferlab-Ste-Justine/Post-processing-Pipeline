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
include { EXOMISER               } from '../modules/local/exomiser'
include { splitMultiAllelics     } from '../modules/local/split_multi_allelics'
include { ENSEMBLVEP_VEP         } from '../modules/nf-core/ensemblvep/vep/main'  
include { tabix  as vep_tabix    } from '../modules/local/tabix'
include { tabix as initial_tabix } from '../modules/local/tabix' 
include { COMBINEGVCFS           } from '../modules/local/combine_gvcfs'
include { GATK4_GENOTYPEGVCFS    } from '../modules/nf-core/gatk4/genotypegvcfs'
include { GATK4_VARIANTFILTRATION} from '../modules/nf-core/gatk4/variantfiltration'

//functions
include { isExomiserToolIncluded } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'
include { isVepToolIncluded } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'

def HOMO_SAPIENS_SPECIES = "homo_sapiens"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
/**
Tag variants that are probable artifacts
In the case of whole genome sequencing data, we use the vqsr procedure.
For whole exome sequencing data, since the vqsr procedure is not supported, we use
a hard filtering approach.
*/
def tagArtifacts(ch_artifact_input, hardFilters, pathFasta, pathFai, pathDict) {
    def ch_vqsr_input = ch_artifact_input.filter{it[0].sequencingType == "WGS"}.map{ meta, vcf, tbi -> [meta, [vcf,tbi]]}
    def ch_variantfiltration_input = ch_artifact_input.filter{it[0].sequencingType == "WES"}

    def ch_vqsr_output = VQSR(ch_vqsr_input)

    def ch_gatk4_variantfiltration_output = GATK4_VARIANTFILTRATION(
        ch_variantfiltration_input,
        [[:], pathFasta],
        [[:], pathFai],
        [[:], pathDict])
        
    def ch_variantfiltration_output =  ch_gatk4_variantfiltration_output.vcf.join(ch_gatk4_variantfiltration_output.tbi)
       .map{ meta, vcf, tbi -> [meta, [vcf,tbi]]}

    return ch_vqsr_output.concat(ch_variantfiltration_output)
}

def exomiser(inputChannel, 
    exomiser_genome,
    exomiser_data_version,
    exomiser_data_dir, 
    analysis_wes_path, 
    analysis_wgs_path,
    local_frequency_file,
    local_frequency_index_file,
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

    return EXOMISER(ch_input_for_exomiser,
        file(exomiser_data_dir),
        exomiser_genome,
        exomiser_data_version,
        [local_frequency_file, local_frequency_index_file],
        remm_input,
        cadd_input
    )  
}

def vep(input_channel, vep_genome, vep_species, path_fasta, vep_cache, vep_cache_version) {
    
    def ch_input_for_vep  = input_channel.map{meta, files ->
        def vcf_file = files.find { it.name.endsWith("vcf.gz") }
        def custom_extra_files = [] 
        [meta, vcf_file, custom_extra_files]
    }
  
    return ENSEMBLVEP_VEP(
        ch_input_for_vep, 
        vep_genome,
        vep_species,
        vep_cache_version,
        vep_cache,
        [[:], path_fasta],  // meta2, fasta
        [] //extra files
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

    stub:
    """
    touch metadata.txt
    """
}

// We assume that the input gvcf files are indexed
def replicate_excludemnps_output_format(input_channel) {
    def with_tbi = input_channel.filter{meta, vcf -> file(vcf + ".tbi").exists()}
        .map{meta, vcf -> [meta, [file(vcf), file(vcf + ".tbi")]]}

    def tbi_input = input_channel.filter{meta, vcf -> !file(vcf + ".tbi").exists()}
    def tbi_output = initial_tabix(tbi_input)
    def with_generated_tbi = tbi_input.join(tbi_output).map{meta, vcf, tbi -> [meta, [vcf, tbi]]}

    return with_tbi.concat(with_generated_tbi)
}

workflow POSTPROCESSING {
    //Local Temp Params
    def referenceGenome = file(params.referenceGenome)
    def pathReferenceGenomeFasta = file(params.referenceGenome + "/" + params.referenceGenomeFasta)
    def pathReferenceGenomeFai = file(pathReferenceGenomeFasta + ".fai")
    def pathIntervalFile =  params.intervalsFile? file(params.intervalsFile) : [] //The empty list is used if we don't want to use an interval file
    def pathReferenceDict = file(params.referenceGenome + "/" + params.referenceGenomeFasta.substring(0,params.referenceGenomeFasta.indexOf(".")) + ".dict")
    def dbsnpFile = params.dbsnpFile? file(params.dbsnpFile) : []
    def dbsnpFileIndex = params.dbsnpFileIndex? file(params.dbsnpFileIndex) : []
    def exomiserLocalFrequencyFile = params.exomiser_local_frequency_path? file(params.exomiser_local_frequency_path) : []
    def exomiserLocalFrequencyIndexFile = params.exomiser_local_frequency_index_path? file(params.exomiser_local_frequency_index_path) : []
   
    file(params.outdir).mkdirs()

    take:
    ch_samplesheet

    main:

    ch_versions = Channel.empty()

    Channel
    .fromList(workflow.configFiles)
    .collectFile(storeDir: "${params.outdir}/pipeline_info/configs",cache: false)

    writemeta()

    def ch_output_from_excludemnps = params.exclude_mnps ? 
        EXCLUDE_MNPS(ch_samplesheet).ch_output_excludemnps : 
        replicate_excludemnps_output_format(ch_samplesheet)
        
    def grouped_by_family = ch_output_from_excludemnps
         //Create groupkey for the grouptuple and separate the vcf (file[0]) and the index (files[1])
        .map{meta, files -> tuple(groupKey(meta.familyId, meta.sampleSize),meta,files[0],files[1])}
        .groupTuple()
        .map{ familyId, meta, vcf, tbi -> 
        //now that samples are grouped together, we no longer follow sample in meta, and the id no longer needs the sampleId
            def updated_meta = meta[0].findAll{!["sample", "id"].contains(it.key) }
            updated_meta["id"] = updated_meta.familyId
            [updated_meta, vcf.flatten(), tbi.flatten()]}

    //Combine per-sample gVCF files into a multi-sample gVCF file
    def filtered_one = grouped_by_family.filter{it[0].sampleSize == 1}
    def ch_input_for_combinegvcf = grouped_by_family.filter{it[0].sampleSize > 1}    
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
    [[:], dbsnpFile],
    [[:], dbsnpFileIndex]
    ).vcf
    .join(GATK4_GENOTYPEGVCFS.out.tbi)

    //tag variants that are probable artifacts
    def ch_output_from_tagArtifacts = tagArtifacts(ch_output_from_genotypegvcf, params.hardFilters,pathReferenceGenomeFasta,pathReferenceGenomeFai,pathReferenceDict)
    //tag frequent mutations in the population
    def ch_output_from_splitMultiAllelics = splitMultiAllelics(ch_output_from_tagArtifacts, referenceGenome)

    //Annotating mutations
    if (isVepToolIncluded()) {
        def vep_cache = file(params.vep_cache)

        def ch_output_from_vep = vep(
            ch_output_from_splitMultiAllelics, 
            params.vep_genome,
            HOMO_SAPIENS_SPECIES,
            pathReferenceGenomeFasta, 
            vep_cache,
            params.vep_cache_version
        )
        vep_tabix(ch_output_from_vep.vcf)
    }

    if (isExomiserToolIncluded()) {
        exomiser(ch_output_from_splitMultiAllelics, 
            params.exomiser_genome,
            params.exomiser_data_version,
            params.exomiser_data_dir,
            params.exomiser_analysis_wes,
            params.exomiser_analysis_wgs,
            exomiserLocalFrequencyFile,
            exomiserLocalFrequencyIndexFile,
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
