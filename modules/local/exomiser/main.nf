process EXOMISER {

    label 'process_low'
 
    input:
    tuple val(meta), path(vcfFile), path(phenoFile), path(analysisFile)
    path datadir
    val exomiserGenome
    val exomiserDataVersion
    
    // If remm/cadd version is specified, remm/cadd reference file(s) path(s) will be inferred from the given filename(s)
    // and passed to the exomiser cli. Each remm/cadd reference file should have a corresponding .tbi index file.
    // Note that, if nextflow adds support for optional paths, one might prefer to pass the full paths explicitly.
    tuple val(remmVersion), val(remmFileName) 
    tuple val(caddVersion), val(caddSnvFileName),val(caddIndelFileName)

    output:
    tuple val(meta), path("results/*vcf.gz")         , optional:true, emit: vcf
    tuple val(meta), path("results/*vcf.gz.tbi")     , optional:true, emit: tbi
    tuple val(meta), path("results/*html")           , optional:true, emit: html
    tuple val(meta), path("results/*json")           , optional:true, emit: json
    tuple val(meta), path("results/*genes.tsv")      , optional:true, emit: genetsv
    tuple val(meta), path("results/*variants.tsv")   , optional:true, emit: variantstsv
    path("versions.yml")            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def exactVcfFile = vcfFile.find { it.name.endsWith("vcf.gz") }

    def remmArgs = ""
    if (remmVersion) {
        log.info("Using REMM version {}", remmVersion)
        remmArgs += "--exomiser.remm.version=\"${remmVersion}\""
        remmArgs += " --exomiser.${exomiserGenome}.remm-path=/`pwd`/${datadir}/remm/${remmFileName}"
    }

    def caddArgs = ""
    if (caddVersion) {
        log.info("Using CADD version {}", caddVersion)
        caddArgs += "--cadd.version=\"${caddVersion}\""
        caddArgs += " --exomiser.${exomiserGenome}.cadd-snv-path=/`pwd`/${datadir}/cadd/${caddVersion}/${caddSnvFileName}"
        caddArgs += " --exomiser.${exomiserGenome}.cadd-indel-path=/`pwd`/${datadir}/cadd/${caddVersion}/${caddIndelFileName}"
    }
    """
    #!/bin/bash -eo pipefail

    java -cp \$( cat /app/jib-classpath-file ) \$( cat /app/jib-main-class-file ) \\
        --vcf ${exactVcfFile} \\
        --assembly "${params.exomiser_genome}" \\
        --analysis "${analysisFile}" \\
        --sample ${phenoFile} \\
        --output-format=HTML,JSON,TSV_GENE,TSV_VARIANT,VCF \\
        --exomiser.data-directory=/`pwd`/${datadir} \\
        ${remmArgs} \\
        ${caddArgs} \\
        --exomiser.${exomiserGenome}.data-version="${exomiserDataVersion}" \\
        --exomiser.phenotype.data-version="${exomiserDataVersion}" \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        "exomiser": "\$(cat /EXOMISER_VERSION.txt)"
    END_VERSIONS
    """

    stub:
    def familyId = meta.familyId
    """
    #!/bin/bash -eo pipefail
    mkdir results
    touch results/${familyId}.splitted-exomiser.genes.tsv
    touch results/${familyId}.splitted-exomiser.html
    touch results/${familyId}.splitted-exomiser.json
    touch results/${familyId}.splitted-exomiser.variants.tsv
    touch results/${familyId}.splitted-exomiser.vcf.gz
    touch results/${familyId}.splitted-exomiser.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       "exomiser": "\$(cat /EXOMISER_VERSION.txt)"
    END_VERSIONS
    """
}