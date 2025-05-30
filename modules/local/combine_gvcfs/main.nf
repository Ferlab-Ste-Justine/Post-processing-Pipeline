process COMBINEGVCFS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gatk4:4.5.0.0--py36hdfd78af_0':
        'biocontainers/gatk4:4.5.0.0--py36hdfd78af_0' }"

    input:
    tuple val(meta), path(vcf), path(vcf_idx)
    path  fasta
    path  fai
    path  dict
    path interval

    output:
    tuple val(meta), path("*.combined.g.vcf.gz"), emit: combined_gvcf
    tuple val(meta), path("*.tbi"),               emit: tbi
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_list = vcf.collect{"--variant $it"}.join(' ')
    def interval_options = interval ? "--intervals $interval" : ""

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK COMBINEGVCFS] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData" \\
        CombineGVCFs \\
        $input_list \\
        --output ${prefix}.combined.g.vcf.gz \\
        --reference ${fasta} \\
        --tmp-dir . \\
        $interval_options \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_list = vcf.collect{"--variant $it"}.join(' ')
    """
    touch ${prefix}.combined.g.vcf.gz
    touch ${prefix}.combined.g.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """       

}
