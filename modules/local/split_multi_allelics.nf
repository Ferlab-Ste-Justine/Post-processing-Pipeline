// This module does not follow nf-core standards. We plan to fix or replace it with an nf-core module in the future.
process splitMultiAllelics{
    label 'process_medium'

    input:
    tuple val(meta), path(vcfFile)
    path referenceGenome

    output:
    tuple val(meta), path("*splitted.vcf*")

    script:
    def familyId = meta.familyId
    def exactVcfFile = vcfFile.find { it.name.endsWith("vcf.gz") }
    """
    set -e
    echo $familyId > file
    bcftools annotate -x FORMAT/PRI ${exactVcfFile} | bcftools norm -c w -m -any -f $referenceGenome/${params.referenceGenomeFasta} --old-rec-tag OLD_RECORD --output-type z --output ${familyId}.normed.vcf.gz  
    bcftools view --min-ac 1 --output-type z --output ${familyId}.splitted.vcf.gz ${familyId}.normed.vcf.gz
    bcftools index -t ${familyId}.splitted.vcf.gz
    """
    
    stub:
    def familyId = meta.familyId
    """
    touch ${familyId}.splitted.vcf.gz
    touch ${familyId}.splitted.vcf.gz.tbi
    """
}