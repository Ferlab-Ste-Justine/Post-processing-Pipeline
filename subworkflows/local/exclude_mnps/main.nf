include { BCFTOOLS_FILTER} from '../../../modules/nf-core/bcftools/filter/main'
include { BCFTOOLS_NORM } from '../../../modules/nf-core/bcftools/norm/main'    
/**
Separates MNPs into several SNP that will be analyzed separately

    Input: [meta, input.vcf.gz]
    Output: [meta, [output.vcf.gz, output.vcf.gz.tbi]]
*/
workflow EXCLUDE_MNPS {
    take:
        input // channel: [meta,  .gvcf.gz]
    main:
    versions = Channel.empty()
    def reference_path = file("${params.referenceGenome}/${params.referenceGenomeFasta}")
    BCFTOOLS_FILTER(input)

    def ch_bcftoolsfilter_for_bcftoolsnorm = BCFTOOLS_FILTER.out.vcf.join(BCFTOOLS_FILTER.out.tbi)

    BCFTOOLS_NORM(ch_bcftoolsfilter_for_bcftoolsnorm, [[:], reference_path])
    ch_output_excludemnps = BCFTOOLS_NORM.out.vcf.join(BCFTOOLS_NORM.out.tbi)
        .map{meta, vcf, tbi ->[meta,[vcf,tbi]]}

    versions = versions.mix(BCFTOOLS_FILTER.out.versions)
    versions = versions.mix(BCFTOOLS_NORM.out.versions)
    emit:
        ch_output_excludemnps // channel: [meta,  [.vcf.gz, .vcf.gz.tbi]]
        versions
}
