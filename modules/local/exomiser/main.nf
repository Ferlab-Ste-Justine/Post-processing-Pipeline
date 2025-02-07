process EXOMISER {

    label 'process_medium'
 
    input:
    tuple val(meta), path(vcfFile), path(indexFile), path(phenoFile), path(analysisFile)
    path datadir
    val exomiserGenome
    val exomiserDataVersion

    // If specified, the local frequency file path will be inferred from the given path and passed to the exomiser cli.
    // It is expected that the file has a corresponding .tbi index file.
    tuple path(localFrequencyPath), path(localFrequencyIndexPath)

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
    def applicationPropertiesArgs = task.ext.application_properties_args ?: ''

    def localFrequencyFileArgs = "" 
    if (localFrequencyPath) {
        log.info("Using LOCAL frequency file {}", localFrequencyPath)
        localFrequencyFileArgs = "--exomiser.${exomiserGenome}.local-frequency-path=/`pwd`/${localFrequencyPath}"
    }

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

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[EXOMISER] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }

    // Note: specifying the extra options (args) at the beginning because output options are ignored when they are passed at the end.
    """
    #!/bin/bash -eo pipefail

    java -Xmx${avail_mem}M -cp \$( cat /app/jib-classpath-file ) \$( cat /app/jib-main-class-file ) \\
        --vcf ${vcfFile} \\
        --assembly "${exomiserGenome}" \\
        --analysis "${analysisFile}" \\
        --sample ${phenoFile} \\
        --output-format=HTML,JSON,TSV_GENE,TSV_VARIANT,VCF \\
        ${args} \\
        --exomiser.data-directory=/`pwd`/${datadir} \\
        ${localFrequencyFileArgs} \\
        ${remmArgs} \\
        ${caddArgs} \\
        --exomiser.${exomiserGenome}.data-version="${exomiserDataVersion}" \\
        --exomiser.phenotype.data-version="${exomiserDataVersion}" \\
        ${applicationPropertiesArgs}

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
    touch results/${familyId}.exomiser.genes.tsv
    touch results/${familyId}.exomiser.html
    touch results/${familyId}.exomiser.json
    touch results/${familyId}.exomiser.variants.tsv
    touch results/${familyId}.exomiser.vcf.gz
    touch results/${familyId}.exomiser.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       "exomiser": "\$(cat /EXOMISER_VERSION.txt)"
    END_VERSIONS
    """
}
