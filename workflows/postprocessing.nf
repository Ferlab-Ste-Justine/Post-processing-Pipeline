/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { EXCLUDE_MNPS           } from "../subworkflows/local/exclude_mnps"
include { VQSR                   } from "../subworkflows/local/vqsr"
include { hardFiltering          } from '../modules/local/hardFilter'
include { splitMultiAllelics     } from '../modules/local/vep'
include { vep                    } from '../modules/local/vep'
include { tabix                  } from '../modules/local/vep'
include { COMBINEGVCFS           } from '../modules/local/combinegvcfs'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*
/**
Keep only SNP and Indel 
*/
process genotypeGVCF {
    label 'geno'

    input:
    tuple val(meta), path(gvcfFile)
    path referenceGenome

    output:
    tuple val(meta), path("*genotyped.vcf.gz*")

    script:
    def familyId = meta.familyId
    def args = task.ext.args ?: ''
    def argsjava = task.ext.argsjava ?: ''
    def exactGvcfFile = gvcfFile.find { it.name.endsWith("vcf.gz") }

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK GenotypeGVCFs] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    echo $familyId > file
    gatk -version
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData $argsjava" \\
        GenotypeGVCFs \\
        -R $referenceGenome/${params.referenceGenomeFasta} \\
        -V $exactGvcfFile \\
        -O ${familyId}.genotyped.vcf.gz \\
        $args
    """


    stub:
    def familyId = meta.familyId
    def exactGvcfFile = gvcfFile.find { it.name.endsWith("vcf.gz") }
    """
    touch ${familyId}.genotyped.vcf.gz
    """
}

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
    println pathIntervalFile
    println pathReferenceGenomeFasta
    def vepCache = file(params.vepCache)
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
    filtered = EXCLUDE_MNPS(ch_samplesheet).ch_output_excludemnps
        .map{meta, files -> tuple(groupKey(meta.familyId, meta.sampleSize),meta,files[0],files[1])}
        .groupTuple()
        .map{ familyId, meta, vcf, tbi -> 
        //now that samples are grouped together, we no longer follow sample in meta, and the id no longer needs the sampleId
            [
                meta[0].findAll{it.key != "sample"}.findAll{it.key != "id"}, //meta
                vcf.flatten(),
                tbi.flatten(),                                               //files
            ]}
        .map{meta,vcf,tbi -> 
            [
                meta+[id: meta.familyId],vcf,tbi               //we replace the sampleID that was removed
            ]}
    
    filtered_one = filtered.filter{it[0].sampleSize == 1}.map{meta,vcf,tbi -> [meta,[vcf[0],tbi[0]]]}
    filtered_mult = filtered.filter{it[0].sampleSize > 1}
    //Combine per-sample gVCF files into a multi-sample gVCF file
    
    DB = COMBINEGVCFS(filtered_mult, pathReferenceGenomeFasta,pathReferenceGenomeFai,pathReferenceDict,pathIntervalFile)
                    .combined_gvcf.join(COMBINEGVCFS.out.tbi)
                    .map{meta, gvcf,tbi -> [meta,[gvcf, tbi]]}
                    .concat(filtered_one)

    //Perform joint genotyping on one or more samples
    vcf = genotypeGVCF(DB, referenceGenome)
    //tag variants that are probable artifacts
    vcfWithTags = tagArtifacts(vcf, params.hardFilters)
    //tag frequent mutations in the population
    s = splitMultiAllelics(vcfWithTags, referenceGenome) 

    //Annotating mutations
    vep(s, referenceGenome, vepCache)
    tabix(vep.out) 
  
    emit:
    tabix.out

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
