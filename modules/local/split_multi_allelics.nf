// This module does not follow nf-core standards. We plan to fix or replace it with an nf-core module in the future.
process splitMultiAllelics{
    label 'process_single'

    input:
    tuple val(meta), path(vcf), path(tbi)
    path referenceGenome

    output:
    tuple val(meta), path("*splitted.vcf.gz"), path("*splitted.vcf.gz.tbi")

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    set -e
    echo $prefix > file
    bcftools annotate -x FORMAT/PRI ${vcf} | bcftools norm -c w -m -any -f $referenceGenome/${params.referenceGenomeFasta} --old-rec-tag OLD_RECORD --output-type z --output ${prefix}.normed.vcf.gz  
    bcftools view --min-ac 1 --output-type z --output ${prefix}.splitted.vcf.gz ${prefix}.normed.vcf.gz
    bcftools index -t ${prefix}.splitted.vcf.gz
    """
    
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.splitted.vcf.gz
    touch ${prefix}.splitted.vcf.gz.tbi
    """
}