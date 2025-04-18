// This module does not follow nf-core standards. We plan to fix or replace it with nf-core modules in the future.


/**
Build a recalibration model to score Indel variant quality for filtering purposes

Note: pre-requisite step for applyVQSRIndel
*/
process variantRecalibratorIndel {
    label 'medium'


    input:
    tuple val(meta), path(vcf)
    path referenceGenome
    path broadResource

    output:
    tuple val(meta), path("*.recal*"), path("*.tranches")
    
    script:
    def prefix = meta.familyId
    def args = task.ext.args ?: ''
    def argsjava = task.ext.args ?: ''
    def exactVcfFile = vcf.find { it.name.endsWith("vcf.gz") }
    def tranches = ["100.0","99.95","99.9","99.5","99.0","97.0","96.0","95.0","94.0"].collect{"-tranche $it"}.join(' ')
    def annotationValues = ["FS","ReadPosRankSum","MQRankSum","QD","SOR","DP"].collect{"-an $it"}.join(' ')

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK VariantRecalibrator] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    set -e
    echo $prefix > file
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData $argsjava" \\
        VariantRecalibrator \\
        $tranches \\
        -R $referenceGenome/${params.referenceGenomeFasta} \\
        -V ${exactVcfFile} \\
        --trust-all-polymorphic \\
        --resource:mills,known=false,training=true,truth=true,prior=12 ${broadResource}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \\
        --resource:axiomPoly,known=false,training=true,truth=false,prior=10 ${broadResource}/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz \\
        --resource:dbsnp,known=true,training=false,truth=false,prior=2 ${broadResource}/Homo_sapiens_assembly38.dbsnp138.vcf \\
        $annotationValues \\
        --max-gaussians 4 \\
        -mode INDEL \\
        -O ${prefix}.recal \\
        --tranches-file ${prefix}.tranches \\
        $args
    """

    stub:
    def prefix = meta.familyId
    """
    touch ${prefix}.recal
    touch ${prefix}.tranches
    """
}

/*
Apply a score cutoff to filter SNP variants based on a recalibration table
*/
process applyVQSRSNP {
    label 'medium'
    

    input:
    tuple val(meta), path(recal), path(tranches), path(vcf)

    output:
    tuple val(meta),path("*.snp.vqsr_${params.TSfilterSNP}.vcf.gz*")

    script:
    def prefix = meta.familyId
    def args = task.ext.args ?: ''
    def argsjava = task.ext.args ?: ''
    def exactVcfFile = vcf.find { it.name.endsWith("vcf.gz") }
    def exactRecal = recal.find { it.name.endsWith("recal") }

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK ApplyVQSR] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    set -e
    echo $prefix > file
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData $argsjava" \\
        ApplyVQSR \\
        -V ${exactVcfFile} \\
        --recal-file ${exactRecal} \\
        -mode SNP \\
        --tranches-file ${tranches} \\
        --truth-sensitivity-filter-level ${params.TSfilterSNP} \\
        --create-output-variant-index true \\
        -O ${prefix}.snp.vqsr_${params.TSfilterSNP}.vcf.gz \\
        $args
    """
    stub:
    def prefix = meta.familyId
    """
    touch ${prefix}.snp.vqsr_${params.TSfilterSNP}.vcf.gz
    """

}

/*
Apply a score cutoff to filter Indel variants based on a recalibration table
*/
process applyVQSRIndel {
    label 'medium'

    container 'broadinstitute/gatk'

    input:
    tuple val(meta), path(recal), path(tranches), path(vcf)

    output:
    tuple val(meta), path("*.snpindel.vqsr_${params.TSfilterINDEL}.vcf.gz*")

    script:
    def prefix = meta.familyId
    def args = task.ext.args ?: ''
    def argsjava = task.ext.args ?: ''
    def exactVcfFile = vcf.find { it.name.endsWith("vcf.gz") }
    def exactRecal = recal.find { it.name.endsWith("recal") }

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK ApplyVQSR] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    set -e
    echo $prefix > file
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData $argsjava" \\
        ApplyVQSR \\
        -V ${exactVcfFile} \\
        --recal-file ${exactRecal} \\
        -mode INDEL \\
        --tranches-file ${tranches} \\
        --truth-sensitivity-filter-level ${params.TSfilterINDEL} \\
        --create-output-variant-index true \\
        -O ${prefix}.snpindel.vqsr_${params.TSfilterINDEL}.vcf.gz \\
        $args
    """
    stub:
    def prefix = meta.familyId
    """
    touch ${prefix}.snpindel.vqsr_${params.TSfilterINDEL}.vcf.gz
    """
}