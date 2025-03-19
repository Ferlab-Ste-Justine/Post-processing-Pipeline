include { BCFTOOLS_FILTER} from '../../../modules/nf-core/bcftools/filter/main'
include { BCFTOOLS_NORM } from '../../../modules/nf-core/bcftools/norm/main'    
/**
Separates MNPs into several SNP that will be analyzed separately.
Also remove fake MNPs introduced by some callers. 

    Input: [meta, input.vcf.gz]
    Output: [meta, [output.vcf.gz, output.vcf.gz.tbi]]
*/
workflow HANDLE_MNPS {
    take:
        input // channel: [meta, vcf, tbi]
        skip // boolean
        path_reference_genome_fasta
    main:
    
    def ch_versions = Channel.empty()
    def ch_output =  input.map{meta, vcf, tbi -> [meta, [vcf, tbi]]}

    if(!skip){

        // Will remove fake MNPs introduced by some callers
        BCFTOOLS_FILTER(input.map{meta, vcf, tbi -> [meta, vcf]})
        
        // Will separate MNPs into several SNPs that will be analyzed separately
        def ch_bcftoolsfilter_for_bcftoolsnorm = BCFTOOLS_FILTER.out.vcf.join(BCFTOOLS_FILTER.out.tbi)
        BCFTOOLS_NORM(ch_bcftoolsfilter_for_bcftoolsnorm, [[:], path_reference_genome_fasta])
        ch_output = BCFTOOLS_NORM.out.vcf.join(BCFTOOLS_NORM.out.tbi)
            .map{meta, vcf, tbi ->[meta,[vcf,tbi]]}

        ch_versions = ch_versions.mix(BCFTOOLS_FILTER.out.versions)
        ch_versions = ch_versions.mix(BCFTOOLS_NORM.out.versions)
    }

    emit:
        output = ch_output // channel: [meta,  [vcf, tbi]]
        versions = ch_versions
}