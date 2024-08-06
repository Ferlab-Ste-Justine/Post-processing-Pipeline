/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

include { VQSR } from "../subworkflows/local/vqsr"
include { hardFiltering } from '../modules/local/hardFilter'
include { splitMultiAllelics        } from '../modules/local/vep'
include { vep                       } from '../modules/local/vep'
include { tabix                     } from '../modules/local/vep'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process excludeMNPs {
    label 'medium'
    
    input:
    tuple val(meta), path(gvcfFile)

    output:
    tuple val(meta), path("*filtered.vcf.gz*")

    script:
    def familyId = meta.familyId
    print(familyId)
    def sample = meta.sample
    def exactGvcfFile = gvcfFile.find { it.name.endsWith("vcf.gz") }
    """
    set -e
    echo $familyId > file
    bcftools filter -e 'strlen(REF)>1 & strlen(REF)==strlen(ALT) & TYPE="snp"' ${exactGvcfFile} | bcftools norm -d any -O z -o ${familyId}.${sample}.filtered.vcf.gz
    bcftools index -t ${familyId}.${sample}.filtered.vcf.gz
    """
    stub:
    def familyId = meta.familyId
    def sample = meta.sample
    def exactGvcfFile = gvcfFile.find { it.name.endsWith("vcf.gz") }
    """
    touch ${familyId}.${sample}.filtered.vcf.gz
    touch ${familyId}.${sample}.filtered.vcf.gz.tbi
    """

}

/**
Combine per-sample gVCF files into a multi-sample gVCF file 
*/
process importGVCF {

    label 'medium'

    input:
    tuple val (meta), path(gvcfFiles)
    path referenceGenome
    path broadResource

    output:
    tuple val (meta), path("*combined.gvcf.gz*")

    script:
    def familyId = meta.familyId
    def args = task.ext.args ?: ''
    def argsjava = task.ext.args ?: ''
    def exactGvcfFiles = gvcfFiles.findAll { it.name.endsWith("vcf.gz") }.collect { "-V $it" }.join(' ')

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK CombineGVCFs] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }


    """
    echo $familyId > file
    gatk -version
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData $argsjava" \\
        CombineGVCFs \\
        -R $referenceGenome/${params.referenceGenomeFasta} \\
        $exactGvcfFiles \\
        -O ${familyId}.combined.gvcf.gz \\
        -L $broadResource/${params.intervalsFile} \\
        $args
    """ 


    stub:
    def familyId = meta.familyId
    def exactGvcfFiles = gvcfFiles.findAll { it.name.endsWith("vcf.gz") }.collect { "-V $it" }.join(' ')

    """
    touch ${familyId}.combined.gvcf.gz
    """       

}    


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
    def argsjava = task.ext.args ?: ''
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
    referenceGenome = file(params.referenceGenome)
    broad = file(params.broad)
    vepCache = file(params.vepCache)
    file(params.outdir).mkdirs()

    take:
    ch_samplesheet

    main:

    ch_versions = Channel.empty()

    Channel
    .fromList(workflow.configFiles)
    .collectFile(storeDir: "${params.outdir}/pipeline_info/configs",cache: false)

    writemeta()
    filtered = excludeMNPs(ch_samplesheet)    
                    .map{meta, files -> tuple( groupKey(meta.familyId, meta.sampleSize),meta,files)}
                    .groupTuple()
                    .map{ familyId, metas, files -> //now that samples are grouped together, we no longer follow sample in meta
                        [
                            metas[0].findAll{it.key != "sample"}, //meta
                            files.flatten()]}                     //files
    //Using 2 as threshold because we have 2 files per patient (gcvf.gz, gvcf.gz.tbi)
    filtered_one = filtered.filter{it.meta.sampleSize == 1}
    filtered_mult = filtered.filter{it.meta.sampleSize > 1}
    //Combine per-sample gVCF files into a multi-sample gVCF file
    DB = importGVCF(filtered_mult, referenceGenome,broad)
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
