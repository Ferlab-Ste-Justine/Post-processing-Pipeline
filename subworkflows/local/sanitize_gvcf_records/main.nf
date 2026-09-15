include { BCFTOOLS_FILTER } from '../../../modules/nf-core/bcftools/filter/main'
include { BCFTOOLS_NORM   } from '../../../modules/nf-core/bcftools/norm/main'

// BCFTOOLS_FILTER drops gVCF records missing the required <NON_REF> allele
// (e.g. the ~0.005% malformed records observed in DRAGEN 4.4.7 output, which
// otherwise make GATK4_GENOTYPEGVCFS fail with "the list of input alleles
// must contain <NON_REF>" -- BIOINFO-222). BCFTOOLS_NORM then left-aligns
// indels and removes duplicate-position records (-d all).
workflow SANITIZE_GVCF_RECORDS {
    take:
        ch_input  // channel: (val(meta), path(vcf))
        ch_fasta  // tuple:   (val(meta2), path(fasta))

    main:
        ch_versions = channel.empty()

        BCFTOOLS_FILTER(ch_input)
        ch_versions = ch_versions.mix(BCFTOOLS_FILTER.out.versions)

        ch_norm_input = BCFTOOLS_FILTER.out.vcf.join(BCFTOOLS_FILTER.out.tbi)

        BCFTOOLS_NORM(ch_norm_input, ch_fasta)
        ch_versions = ch_versions.mix(BCFTOOLS_NORM.out.versions)

        ch_vcf_tbi = BCFTOOLS_NORM.out.vcf.join(BCFTOOLS_NORM.out.tbi)

    emit:
        vcf_tbi  = ch_vcf_tbi  // channel: (val(meta), vcf, tbi)
        versions = ch_versions // channel: [ versions.yml ]
}
