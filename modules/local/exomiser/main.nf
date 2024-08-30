
process exomiser {

    label 'process_low'
 

    input:
    tuple val(meta), path(vcfFile)
    path(analysis_file)
    path(datadir)
    val(exomiserversion)
    val(dataversion)
    val(genome)
    path(pedigree_file)

    output:
    tuple val(meta)
    path("results/*vcf.gz")         , emit: vcf
    path("results/*vcf.gz.tbi")     , emit: tbi
    path("results/*html")           , optional:true, emit: html
    path("results/*json")           , optional:true, emit: json
    path("results/*genes.tsv")      , optional:true, emit: genetsv
    path("results/*variants.tsv")   , optional:true, emit: variantstsv
    // TODO nf-core: List additional required output channels/values here

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def exactVcfFile = vcfFile.find { it.name.endsWith("vcf.gz") }
    def pedigree_command = pedigree_file ? "--ped $pedigree_file" : ""
    """
    #!/bin/bash -eo pipefail
    ls
    java -cp \$( cat /app/jib-classpath-file ) \$( cat /app/jib-main-class-file ) \\
        --vcf ${exactVcfFile} \\
        --assembly "${genome}"  \\
        --analysis ${analysis_file} \\
        --exomiser.data-directory=/`pwd`/${datadir} \\
        --exomiser.hg19.data-version=${dataversion} \\
        --exomiser.hg38.data-version=${dataversion} \\
        --exomiser.phenotype.data-version=${dataversion} \\
        --
        ${pedigree_command} \\
        ${args}

    ls
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
    """

}
