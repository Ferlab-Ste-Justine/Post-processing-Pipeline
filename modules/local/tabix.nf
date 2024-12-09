// This module does not follow nf-core standards. We plan to fix or replace it with an nf-core module in the future.
process tabix {
    label 'tiny'

    input:
    tuple val(meta), path(vcfFile)

    output:
    tuple val(meta), path("*.tbi")

    script:
    def args = task.ext.args ?: ''

    """
    tabix \\
        $vcfFile \\
        $args
    """
    stub:
    """
    touch ${vcfFile}.tbi
    """
} 