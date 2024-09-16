
process EXOMISER {

    label 'process_low'
 

    input:
    tuple val(meta), path(vcfFile), path(phenofile)
    path(analysis_file)
    path(datadir)


    output:
    val(meta)
    path("results/*vcf.gz")         , optional:true, emit: vcf
    path("results/*vcf.gz.tbi")     , optional:true, emit: tbi
    path("results/*html")           , optional:true, emit: html
    path("results/*json")           , optional:true, emit: json
    path("results/*genes.tsv")      , optional:true, emit: genetsv
    path("results/*variants.tsv")   , optional:true, emit: variantstsv
    path "versions.yml"              , emit: versions
    // TODO nf-core: List additional required output channels/values here

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def exactVcfFile = vcfFile.find { it.name.endsWith("vcf.gz") }

    """
    #!/bin/bash -eo pipefail

    java -cp \$( cat /app/jib-classpath-file ) \$( cat /app/jib-main-class-file ) \\
        --vcf ${exactVcfFile} \\
        --assembly "${params.genome}" \\
        --analysis "${analysis_file}" \\
        --sample ${phenofile} \\
        --output-format=HTML,JSON,TSV_GENE,TSV_VARIANT,VCF \\
        --exomiser.data-directory=/`pwd`/${datadir} \\
        --exomiser.hg19.data-version="${params.exomiser_data_version}" \\
        --exomiser.hg38.data-version="${params.exomiser_data_version}" \\
        --exomiser.phenotype.data-version="${params.exomiser_data_version}" \\
        ${args}
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        exomiser: "${params.exomiser_version}"
    END_VERSIONS
    """

    stub:
    def familyId = meta.familyId
    """
    #!/bin/bash -eo pipefail
    mkdir results
    touch results/${familyId}-PASS_ONLY.genes.tsv
    touch results/${familyId}-PASS_ONLY.html
    touch results/${familyId}-PASS_ONLY.json
    touch results/${familyId}-PASS_ONLY.variants.tsv
    touch results/${familyId}-PASS_ONLY.vcf.gz
    touch results/${familyId}-PASS_ONLY.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        exomiser: "${params.exomiser_version}"
    END_VERSIONS
    """

}