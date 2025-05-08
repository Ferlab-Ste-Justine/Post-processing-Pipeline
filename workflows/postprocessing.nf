/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//modules and subworkflows
include { paramsSummaryMap        } from 'plugin/nf-validation'
include { paramsSummaryMultiqc    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML  } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { EXCLUDE_MNPS            } from "../subworkflows/local/exclude_mnps"
include { VQSR                    } from "../subworkflows/local/vqsr"
include { BCFTOOLS_VIEW           } from '../modules/nf-core/bcftools/view/main' 
include { EXOMISER                } from '../modules/local/exomiser'
include { splitMultiAllelics      } from '../modules/local/split_multi_allelics'
include { VCF_ANNOTATE_ENSEMBLVEP } from '../subworkflows/nf-core/vcf_annotate_ensemblvep/main'   
include { COMBINEGVCFS            } from '../modules/local/combine_gvcfs'
include { GATK4_GENOTYPEGVCFS     } from '../modules/nf-core/gatk4/genotypegvcfs'
include { GATK4_VARIANTFILTRATION } from '../modules/nf-core/gatk4/variantfiltration'
include { ENSEMBLVEP_DOWNLOAD     } from '../modules/nf-core/ensemblvep/download/main'
include { CHANNEL_CREATE_CSV as CHANNEL_CREATE_CSV_VEP } from '../subworkflows/local/channel_create_csv'
include { CHANNEL_CREATE_CSV as CHANNEL_CREATE_CSV_GENOTYPE } from '../subworkflows/local/channel_create_csv'
//functions
include { isExomiserToolIncluded  } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'
include { isVepToolIncluded       } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'

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

    def ch_vqsr_output = VQSR(ch_vqsr_input, pathFasta, pathFai, pathDict).output

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
    def ch_input_for_exomiser = inputChannel
        .filter{ meta, vcf, tbi -> meta.familypheno} //only run exomiser on families for which a phenopacket file is specified
        .map{meta, vcf, tbi -> [
            meta,
            vcf,
            tbi,
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

    def ch_input_for_vep  = input_channel.map{meta, vcf, tbi -> [meta, vcf, []]}

    return VCF_ANNOTATE_ENSEMBLVEP(
        ch_input_for_vep,  //  meta, vcf, optional_custom_files
        [[:], path_fasta], //  meta2, fasta
        vep_genome,
        vep_species,
        vep_cache_version,
        vep_cache,
        [] //extra files
    ).vcf_tbi
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


def handle_mnps(input_channel, do_exclude_mnps) {
    if(!do_exclude_mnps) {
        return input_channel.map{meta, vcf, tbi -> [meta, [vcf, tbi]]}
    }
    def ch_input_excludemnps = input_channel.map{meta, vcf, tbi -> [meta, vcf]}
    return EXCLUDE_MNPS(ch_input_excludemnps).ch_output_excludemnps
}


/* 
Deal with variations in input file formats, extensions, and the presence or absence of index files.
input: [meta, vcf]
output: [meta, vcf, tbi]
*/
def standardize_input_vcf_files(input_channel) {
    def view_input = input_channel.map{meta,  vcf -> 
        def tbi = file(vcf + ".tbi")
        [meta, vcf, tbi.exists() ? tbi: []]
    }
    def view_output = BCFTOOLS_VIEW(view_input, [], [], [])
    return view_output.vcf.join(view_output.tbi)
}

workflow POSTPROCESSING {

    take:
    ch_samplesheet

    main:
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

    def HOMO_SAPIENS_SPECIES = "homo_sapiens"
    
    file(params.outdir).mkdirs()

    ch_versions = Channel.empty()

    Channel
    .fromList(workflow.configFiles)
    .collectFile(storeDir: "${params.outdir}/pipeline_info/configs",cache: false)

    writemeta()


    if (params.step == 'genotype') {
        def ch_samplesheet_standard = standardize_input_vcf_files(ch_samplesheet)
        
        def ch_output_from_handle_mnps = handle_mnps(ch_samplesheet_standard, params.exclude_mnps)
            
        def grouped_by_family = ch_output_from_handle_mnps
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
        def ch_input_for_genotypegvcf = ch_output_from_combinegvcf.map{meta,vcf,tbi -> [meta,vcf,tbi, pathIntervalFile, []]}
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
        //normalize variants
        ch_output_from_splitMultiAllelics = splitMultiAllelics(ch_output_from_tagArtifacts, referenceGenome)

        // TODO: Refactor splitMultiAllelics and tagArtifacts into subworkflows 
        //create a csv file with the sample information
        // CHANNEL_CREATE_CSV_GENOTYPE(ch_output_from_splitMultiAllelics,"genotyped",params.outdir) 
    }

    if (params.step in ['genotype', 'annotate'] && isVepToolIncluded() ) {

        //Annotating variants with VEP

        // Download VEP cache if download = true. Assuming we want to download even if cache provided. 
        if (params.download_cache) {
            ensemblvep_info = Channel.of([ [ id:"${params.vep_cache_version}_${params.vep_genome}" ], params.vep_genome, HOMO_SAPIENS_SPECIES, params.vep_cache_version ])
            ENSEMBLVEP_DOWNLOAD(ensemblvep_info)
            vep_cache = ENSEMBLVEP_DOWNLOAD.out.cache.collect().map{ _meta, cache -> [ cache ] }
            ch_versions = ch_versions.mix(ENSEMBLVEP_DOWNLOAD.out.versions.first())
        } else {
            vep_cache = file(params.vep_cache)
        }

        //TODO: define input sample
        vcf_for_vep = params.step == 'genotype' ? ch_output_from_splitMultiAllelics : ch_samplesheet // ch_samplesheet will be the csv retrieved from outdir
        ch_output_from_vep = vep(
            vcf_for_vep, 
            params.vep_genome,
            HOMO_SAPIENS_SPECIES,
            pathReferenceGenomeFasta, 
            vep_cache,
            params.vep_cache_version
        )

        CHANNEL_CREATE_CSV_VEP(ch_output_from_vep,"ensemblvep",params.outdir)

    }

    if (params.step in ['genotype', 'annotate', 'exomiser'] && isExomiserToolIncluded()) {

        // op 1 pipeline ran from beginning (step == genotype) and start_from_vep is false -> start from output from multiallelics
        // op 2 pipeline ran from begining OR annotate, vep included and exomiser_start_from_vep == true -> start from ch_output_from_vep
        // op 3 step is exomiser and exomiser_start_from_Vep == false, retrieve ch_samplesheet csv of split multiallelics
        // op 4 step is exomiser and exomiser_start_from vep == true, retrieve ch_samplesheet csv of vep

        if(params.exomiser_start_from_vep){
            log.info("Running the exomiser analysis using the vep annotated vcf file as input")
            ch_exomiser_input = params.step == 'exomiser' ? ch_samplesheet : ch_output_from_vep
        }
        else {
            ch_exomiser_input = params.step == 'exomiser' ? ch_samplesheet : ch_output_from_splitMultiAllelics
        }
        
        exomiser(
            ch_exomiser_input,
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
