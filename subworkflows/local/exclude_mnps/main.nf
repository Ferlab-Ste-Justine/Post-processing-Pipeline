include { BCFTOOLS_FILTER} from '../../../modules/nf-core/bcftools/filter/main'
include { BCFTOOLS_NORM } from '../../../modules/nf-core/bcftools/norm/main'    
/**
Separates MNPs into several SNP that will be analyzed separately

The input and output formats are the same:
    Input: ([meta]  [some.file.vcf.gz, some.file.vcf.gz.tbi])

*/
workflow EXCLUDE_MNPS {
    take:
        input // channel: (val(metas),  [.gvcf.gz])
    main:

        BCFTOOLS_FILTER(input)
        referencepath = file("${params.referenceGenome}/${params.referenceGenomeFasta}")
        ch_reference = input.map{meta,file -> [meta,referencepath]}

        ch_bcftoolsfilter_for_bcftoolsnorm = BCFTOOLS_FILTER.out.vcf.join(BCFTOOLS_FILTER.out.tbi)

        BCFTOOLS_NORM(ch_bcftoolsfilter_for_bcftoolsnorm,ch_reference)
        ch_output_excludemnps = BCFTOOLS_NORM.out.vcf.join(BCFTOOLS_NORM.out.tbi)
            .map{meta, vcf, tbi ->[meta,[vcf,tbi]]}
    emit:
        ch_output_excludemnps // channel: (val(meta),  [.vcf.gz, .vcf.gz.tbi])
}
