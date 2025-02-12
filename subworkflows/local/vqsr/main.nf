include { GATK4_VARIANTRECALIBRATOR as GATK4_VARIANTRECALIBRATOR_SNP} from '../../../modules/nf-core/gatk4/variantrecalibrator/main'
include { variantRecalibratorIndel; applyVQSRIndel; applyVQSRSNP} from '../../../modules/local/vqsr'
include { attachMultiqcReport } from '../../nf-core/utils_nfcore_pipeline/main.nf'

def variantRecalibratorSNP(
    input,
    referenceGenomeFasta,
    referenceGenomeFai,
    referenceGenomeDict,
    resources)
    {
    def resourceVcfs = []
    def resourceTbis = []
    def resourceLabels = []
    resources.each{ it -> 
        def vcfFile = file(it.vcf)
        resourceVcfs.add(vcfFile)
        resourceTbis.add(file(it.index))
        resourceLabels.add("--resource:" + it.labels + " ${vcfFile.getFileName()}")
    }

    def variantRecalibratorInput = input.map{ meta, files -> [meta, files[0], files[1]] }
    def output = GATK4_VARIANTRECALIBRATOR_SNP(
        variantRecalibratorInput,
        resourceVcfs,
        resourceTbis,
        resourceLabels,
        referenceGenomeFasta,
        referenceGenomeFai,
        referenceGenomeDict
    )
    return output.recal
        .join(output.idx)
        .map{meta, recal, recalIdx -> [meta, [recal, recalIdx]]}
        .join(output.tranches)
}


/**
Filter out probable artifacts from the callset using the Variant Quality Score Recalibration (VQSR) procedure

The input and output formats are the same:
    Input: ([meta],  [some.file.vcf.gz, some.file.vcf.gz.tbi])

All output files will be prefixed with the given prefixId.
*/
workflow VQSR {
    take:
        input // channel: (val(meta),  [.vcf.gz, .vcf.gz.tbi])
        referenceGenomeFasta
        referenceGenomeFai
        referenceGenomeDict

    main:
        // Keeping this until we standardize passing reference genome files.
        // We should use referenceGenomeFasta, referenceGenomeFai, and referenceGenomeDict workflow inputs instead.
        def referenceGenome = file(params.referenceGenome)
    
        //If VQSR is not used (i.e. only whole exome data), we allow to avoid passing the broad parameter.
        //This code, however, will be executed anyway, so we need to handle this scenario.
        def broad = params.broad? file(params.broad): ""
 
        // Initializing vqsr_snp_resources to maintain previous behavior that hard-coded these settings. 
        // We couldn't specify these defaults in the config because the broad parameter is null by default.
        // This initialization logic can be removed once all processes are standardized and fully configurable.      
        def vqsr_snp_resources = params.vqsr_snp_resources ?:  [
            [labels: "hapmap,known=false,training=true,truth=true,prior=15", vcf: "${broad}/hapmap_3.3.hg38.vcf.gz", index: "${broad}/hapmap_3.3.hg38.vcf.gz.tbi"],
            [labels: "omni,known=false,training=true,truth=false,prior=12", vcf: "${broad}/1000G_omni2.5.hg38.vcf.gz", index: "${broad}/1000G_omni2.5.hg38.vcf.gz.tbi"],
            [labels: "1000G,known=false,training=true,truth=false,prior=10", vcf: "${broad}/1000G_phase1.snps.high_confidence.hg38.vcf.gz", index: "${broad}/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi"],
            [labels: "dbsnp,known=true,training=false,truth=false,prior=7", vcf: "${broad}/Homo_sapiens_assembly38.dbsnp138.vcf", index: "${broad}/Homo_sapiens_assembly38.dbsnp138.vcf.idx"]
        ]

        def outputRecalibratorSNP = variantRecalibratorSNP(
            input, 
            referenceGenomeFasta,
            referenceGenomeFai,
            referenceGenomeDict,
            vqsr_snp_resources
        )

        def outputSNP = outputRecalibratorSNP
            | join(input)
            | applyVQSRSNP
        output = variantRecalibratorIndel(input, referenceGenome, broad)
            | join(outputSNP)
            | applyVQSRIndel

    emit:
        output // channel: (val(meta),  [.vcf.gz, .vcf.gz.tbi])
}
