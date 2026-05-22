include { GATK4_VARIANTRECALIBRATOR as GATK4_VARIANTRECALIBRATOR_SNP   } from '../../../modules/nf-core/gatk4/variantrecalibrator/main'
include { GATK4_VARIANTRECALIBRATOR as GATK4_VARIANTRECALIBRATOR_INDEL } from '../../../modules/nf-core/gatk4/variantrecalibrator/main'
include { GATK4_APPLYVQSR           as GATK4_APPLYVQSR_SNP             } from '../../../modules/local/gatk4/applyvqsr/main'
include { GATK4_APPLYVQSR           as GATK4_APPLYVQSR_INDEL           } from '../../../modules/local/gatk4/applyvqsr/main'

/**
Filter out probable artifacts from the callset using the Variant Quality Score Recalibration (VQSR) procedure.

ApplyVQSR is run sequentially: SNP recalibration is applied first, then INDEL recalibration
on top of the SNP-recalibrated callset.
*/
workflow VQSR {
    take:
        ch_input                       // channel: (val(meta), vcf, tbi)
        ch_snp_resource_vcfs        // channel: value list of path
        ch_snp_resource_tbis        // channel: value list of path
        ch_snp_resource_labels      // channel: value list of '--resource:label,... <basename>' strings
        ch_indel_resource_vcfs      // channel: value list of path
        ch_indel_resource_tbis      // channel: value list of path
        ch_indel_resource_labels    // channel: value list of '--resource:label,... <basename>' strings
        ch_fasta                    // path: reference fasta
        ch_fai                      // path: reference fasta index
        ch_dict                     // path: reference dict

    main:
        ch_versions = channel.empty()

        // Build the VQSR model for SNPs
        GATK4_VARIANTRECALIBRATOR_SNP(
            ch_input,
            ch_snp_resource_vcfs,
            ch_snp_resource_tbis,
            ch_snp_resource_labels,
            ch_fasta,
            ch_fai,
            ch_dict
        )
        ch_versions = ch_versions.mix(GATK4_VARIANTRECALIBRATOR_SNP.out.versions)

        // Apply the SNP VQSR model
        ch_snp_apply_input = ch_input
            .join(GATK4_VARIANTRECALIBRATOR_SNP.out.recal)
            .join(GATK4_VARIANTRECALIBRATOR_SNP.out.idx)
            .join(GATK4_VARIANTRECALIBRATOR_SNP.out.tranches)

        GATK4_APPLYVQSR_SNP(
            ch_snp_apply_input,
            ch_fasta,
            ch_fai,
            ch_dict
        )
        ch_versions = ch_versions.mix(GATK4_APPLYVQSR_SNP.out.versions)

        // Build the VQSR model for INDELs (on the SNP-recalibrated VCF)
        ch_indel_recal_input = GATK4_APPLYVQSR_SNP.out.vcf.join(GATK4_APPLYVQSR_SNP.out.tbi)

        GATK4_VARIANTRECALIBRATOR_INDEL(
            ch_indel_recal_input,
            ch_indel_resource_vcfs,
            ch_indel_resource_tbis,
            ch_indel_resource_labels,
            ch_fasta,
            ch_fai,
            ch_dict
        )
        ch_versions = ch_versions.mix(GATK4_VARIANTRECALIBRATOR_INDEL.out.versions)

        // Apply the INDEL VQSR model
        ch_indel_apply_input = ch_indel_recal_input
            .join(GATK4_VARIANTRECALIBRATOR_INDEL.out.recal)
            .join(GATK4_VARIANTRECALIBRATOR_INDEL.out.idx)
            .join(GATK4_VARIANTRECALIBRATOR_INDEL.out.tranches)

        GATK4_APPLYVQSR_INDEL(
            ch_indel_apply_input,
            ch_fasta,
            ch_fai,
            ch_dict
        )
        ch_versions = ch_versions.mix(GATK4_APPLYVQSR_INDEL.out.versions)

        ch_output = GATK4_APPLYVQSR_INDEL.out.vcf
            .join(GATK4_APPLYVQSR_INDEL.out.tbi)

    emit:
        vcf_tbi   = ch_output   // channel: (val(meta), vcf, tbi)
        versions = ch_versions // channel: [ versions.yml ]
}
