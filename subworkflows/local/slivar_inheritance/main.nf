include { SLIVAR_EXPR      } from '../../../modules/local/slivar/expr/main'
include { SLIVAR_COMPOUNDHETS     } from '../../../modules/local/slivar/compoundhets/main'

workflow SLIVAR_INHERITANCE {

    take:
    ch_vcf_ped // channel: [ val(meta), vcf, tbi, ped ]
    val_regions_bed
    val_exclude_bed
    val_gnotate_files
    val_js

    main:

    SLIVAR_EXPR(ch_vcf_ped, val_regions_bed, val_exclude_bed, val_gnotate_files, val_js)
    
    ch_compoundhets_in = ch_vcf_ped
        .join(SLIVAR_EXPR.out.vcf)
            .map{ meta, _vcf, _tbi, ped, expr_vcf ->
                    return [meta, expr_vcf, ped]
                }

    SLIVAR_COMPOUNDHETS(ch_compoundhets_in)

    vcf_tbi = SLIVAR_COMPOUNDHETS.out.vcf
        .join(SLIVAR_COMPOUNDHETS.out.tbi)

    emit:
    vcf_tbi         = vcf_tbi           // channel: [ val(meta), [ vcf, tbi ] ]
    expr_summary    = SLIVAR_EXPR.out.summary      // channel: [ val(meta), summary ]
    ch_summary      = SLIVAR_COMPOUNDHETS.out.summary      // channel: [ val(meta), summary ]
}
