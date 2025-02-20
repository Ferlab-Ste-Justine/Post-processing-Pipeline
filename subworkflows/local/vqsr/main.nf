include { GATK4_VARIANTRECALIBRATOR as GATK4_VARIANTRECALIBRATOR_SNP} from '../../../modules/nf-core/gatk4/variantrecalibrator/main'
include { variantRecalibratorIndel; applyVQSRIndel; applyVQSRSNP} from '../../../modules/local/vqsr'
include { attachMultiqcReport } from '../../nf-core/utils_nfcore_pipeline/main.nf'

def getResourceLabels(resources) {
    return resources.collect{it -> "--resource:" + it.labels + " ${file(it.vcf).getFileName()}"}
}

/**
Filter out probable artifacts from the callset using the Variant Quality Score Recalibration (VQSR) procedure

The input and output formats are the same:
    Input: ([meta],  [some.file.vcf.gz, some.file.vcf.gz.tbi])

All output files will be prefixed with the given prefixId.
*/
workflow VQSR {
    take:
        input // channel: (val(meta), [.vcf.gz, .vcf.gz.tbi])
        referenceGenomeFasta
        referenceGenomeFai
        referenceGenomeDict

    main:

        // We need to keep this until we standardize passing reference genome files in all VQSR processes.
        // We should use referenceGenomeFasta, referenceGenomeFai, and referenceGenomeDict workflow inputs instead.
        def referenceGenome = file(params.referenceGenome)
        
        // Check if the broad resource is provided because it can be omitted if only whole exome data is used.
        def broad = params.broad? file(params.broad): ""
 
        // Temporarily initializing vqsr_snp_resources to maintain previous behavior that hard-coded these settings. 
        // We couldn't specify these defaults in the config because the broad parameter is null by default.    
        def vqsrSnpResources = params.vqsr_snp_resources ?:  [
            [labels: "hapmap,known=false,training=true,truth=true,prior=15", vcf: "${params.broad}/hapmap_3.3.hg38.vcf.gz", index: "${params.broad}/hapmap_3.3.hg38.vcf.gz.tbi"],
            [labels: "omni,known=false,training=true,truth=false,prior=12", vcf: "${params.broad}/1000G_omni2.5.hg38.vcf.gz", index: "${params.broad}/1000G_omni2.5.hg38.vcf.gz.tbi"],
            [labels: "1000G,known=false,training=true,truth=false,prior=10", vcf: "${params.broad}/1000G_phase1.snps.high_confidence.hg38.vcf.gz", index: "${params.broad}/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi"],
            [labels: "dbsnp,known=true,training=false,truth=false,prior=7", vcf: "${params.broad}/Homo_sapiens_assembly38.dbsnp138.vcf", index: "${params.broad}/Homo_sapiens_assembly38.dbsnp138.vcf.idx"]
        ]

        def ch_versions = Channel.empty()
        def ch_input = input.map{meta, files -> [meta, files[0], files[1]]}

        // Build the VQSR model for SNP
        GATK4_VARIANTRECALIBRATOR_SNP( 
            ch_input,
            vqsrSnpResources.collect{file(it.vcf)},
            vqsrSnpResources.collect{file(it.index)},
            getResourceLabels(vqsrSnpResources),
            referenceGenomeFasta,
            referenceGenomeFai,
            referenceGenomeDict
        )
        def outputFromRecalibratorSNP = GATK4_VARIANTRECALIBRATOR_SNP.out.recal
            .join(GATK4_VARIANTRECALIBRATOR_SNP.out.idx)
            .map{meta, recal, recalIdx -> [meta, [recal, recalIdx]]}
            .join(GATK4_VARIANTRECALIBRATOR_SNP.out.tranches)
        ch_versions = ch_versions.mix(GATK4_VARIANTRECALIBRATOR_SNP.out.versions)

        // Apply the VQSR model for SNP
        def outputSNP = outputFromRecalibratorSNP.join(input)
            | applyVQSRSNP

        // Build and apply VQSR model on INDEL
        def ch_output = variantRecalibratorIndel(input, referenceGenome, broad)
            | join(outputSNP)
            | applyVQSRIndel

    emit:
        output = ch_output // channel: (val(meta),  [.vcf.gz, .vcf.gz.tbi])
        versions = ch_versions // channel: [ versions.yml ]
}
