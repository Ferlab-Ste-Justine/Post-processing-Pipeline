include { variantRecalibratorIndel; variantRecalibratorSNP; applyVQSRIndel; applyVQSRSNP} from '../../../modules/local/vqsr'

/**
Filter out probable artifacts from the callset using the Variant Quality Score Recalibration (VQSR) procedure

The input and output formats are the same:
    Input: (prefixId,  [some.file.vcf.gz, some.file.vcf.gz.tbi])

All output files will be prefixed with the given prefixId.
*/
workflow VQSR {
    take:
        input // channel: (val(prefixId), va(meta),  [.vcf.gz, .vcf.gz.tbi])
    main:
        ch_input = input.map{id,metas,files -> [id,files]}
        referenceGenome = file(params.referenceGenome)
        broad = file(params.broad)


        outputSNP = variantRecalibratorSNP(input, referenceGenome, broad)
            | join(ch_input)
            | applyVQSRSNP
        ch_outputSNP = outputSNP.map{id,metas,files -> [id,files]}
        output = variantRecalibratorIndel(input, referenceGenome, broad)
            | join(ch_outputSNP)
            | applyVQSRIndel

    emit:
        output // channel: (val(prefixId),  [.vcf.gz, .vcf.gz.tbi])
}
