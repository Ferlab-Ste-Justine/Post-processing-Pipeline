include { variantRecalibratorIndel; variantRecalibratorSNP; applyVQSRIndel; applyVQSRSNP} from '../../../modules/local/vqsr'

/**
Filter out probable artifacts from the callset using the Variant Quality Score Recalibration (VQSR) procedure

The input and output formats are the same:
    Input: ([meta],  [some.file.vcf.gz, some.file.vcf.gz.tbi])

All output files will be prefixed with the given prefixId.
*/
workflow VQSR {
    take:
        input // channel: (val(meta),  [.vcf.gz, .vcf.gz.tbi])
    main:
        referenceGenome = file(params.referenceGenome)

        //If VQSR is not used (i.e. only whole exome data), we allow to avoid passing the broad paramater.
        //This code, however, will be executed anyway, so we need to handle this scenario.
        broad = params.broad? file(params.broad): ""

        outputSNP = variantRecalibratorSNP(input, referenceGenome, broad)
            | join(input)
            | applyVQSRSNP
        output = variantRecalibratorIndel(input, referenceGenome, broad)
            | join(outputSNP)
            | applyVQSRIndel

    emit:
        output // channel: (val(meta),  [.vcf.gz, .vcf.gz.tbi])
}
