/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
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

enum SequencingType {
    WGS,
    WES

    public static boolean contains(String s) {
        for(SequencingType sequencingType in SequencingType.values()){
            if(sequencingType.name().equals(s)){
                return true
            }
        }
        return false
    }
}

def sampleChannel() {    
    return Channel.fromPath(file("$params.input"))
        .splitCsv(sep: '\t', strip: true)
        .map{rowMapperV2(it)}
        .flatMap { it ->
            return it.files.collect{f -> [familyId: it.familyId, sequencingType: it.sequencingType, size: it.files.size(), file: f]};             
        }.multiMap { it ->
            meta: tuple(it.familyId, [size: it.size, sequencingType: it.sequencingType])
            files: tuple(it.familyId, file("${it.file}*"))
        }
}

def rowMapperV2(columns) {
    def sampleSeqType = columns[1].toUpperCase()
    if (!(SequencingType.contains(sampleSeqType))){
        error("Error: Second column of the sample sheet should be either 'WES' or 'WGS'")
        exit(1)
    }
    return [
        familyId: columns[0],
        sequencingType: sampleSeqType.toUpperCase() as SequencingType,
        files: columns[2..-1]
    ]
}

process excludeMNPs {
    label 'medium'
    
    input:
    tuple val(familyId), path(gvcfFile)

    output:
    tuple val(familyId), path("*filtered.vcf.gz*")

    script:
    def exactGvcfFile = gvcfFile.find { it.name.endsWith("vcf.gz") }
    def uuid = UUID.randomUUID().toString()
    // --regions chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22,chrX,chrY
    // bcftools view --exclude-type mnps  ${exactGvcfFile} -O z -o ${familyId}.${uuid}.filtered.gvcf.gz
    """
    set -e
    echo $familyId > file
    bcftools filter -e 'strlen(REF)>1 & strlen(REF)==strlen(ALT) & TYPE="snp"' ${exactGvcfFile} | bcftools norm -d any -O z -o ${familyId}.${uuid}.filtered.vcf.gz
    bcftools index -t ${familyId}.${uuid}.filtered.vcf.gz
    """
    stub:

    def exactGvcfFile = gvcfFile.find { it.name.endsWith("vcf.gz") }
    def uuid = UUID.randomUUID().toString()
    """
    touch ${familyId}.${uuid}.filtered.vcf.gz
    touch ${familyId}.${uuid}.filtered.vcf.gz.tbi
    """

}

/**
Combine per-sample gVCF files into a multi-sample gVCF file 
*/
process importGVCF {

    label 'medium'

    input:
    tuple val(familyId), path(gvcfFiles)
    path referenceGenome
    path broadResource

    output:
    tuple val(familyId), path("*combined.gvcf.gz*")

    script:
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
    tuple val(familyId), path(gvcfFile)
    path referenceGenome

    output:
    tuple val(familyId), path("*genotyped.vcf.gz*")

    script:
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
def tagArtifacts(inputChannel, metadataChannel, hardFilters) {
    def inputSequencingTypes = inputChannel.join(metadataChannel)
    
    def wgs = inputSequencingTypes.filter{it[2].sequencingType == SequencingType.WGS}.map(it -> it.dropRight(1))
    def wes = inputSequencingTypes.filter{it[2].sequencingType == SequencingType.WES}.map(it -> it.dropRight(1))

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
    input
//    tuple val(ch_meta), path(ch_files)

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
/*
    Channel
    .fromList(workflow.configFiles)
    .collectFile(storeDir: "${params.outdir}/pipeline_info/configs",cache: false)

    writemeta()
*/
    sampleChannel().set{ sampleFile }

    filtered = excludeMNPs(sampleFile.files)
                    .join(sampleFile.meta)
                    .map{familyId, files, meta -> tuple( groupKey(familyId, meta.size), files)}
                    .groupTuple()
                    .map{ familyId, files -> tuple(familyId, files.flatten())}

    //Using 2 as threshold because we have 2 files per patient (gcvf.gz, gvcf.gz.tbi)
    filtered_one = filtered.filter{it[1].size() == 2}
    filtered_mult = filtered.filter{it[1].size() > 2}

    //Combine per-sample gVCF files into a multi-sample gVCF file
    DB = importGVCF(filtered_mult, referenceGenome,broad)
                    .concat(filtered_one)


    //Perform joint genotyping on one or more samples
    vcf = genotypeGVCF(DB, referenceGenome)

    //tag variants that are probable artifacts
    vcfWithTags = tagArtifacts(vcf, sampleFile.meta, params.hardFilters)

    //tag frequent mutations in the population
    s = splitMultiAllelics(vcfWithTags, referenceGenome) 

    //Annotating mutations
    vep(s, referenceGenome, vepCache)
    tabix(vep.out) 
    //
    // MODULE: Run FastQC
    //
    /*
    FASTQC (
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
*/
    emit:
    /*
    filtered = filtered // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
    */
    filtered_mult

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
