/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//modules and subworkflows
include { softwareVersionsToYAML  } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { EXCLUDE_MNPS            } from "../subworkflows/local/exclude_mnps"
include { VQSR                    } from "../subworkflows/local/vqsr"
include { SLIVAR_INHERITANCE      } from '../subworkflows/local/slivar_inheritance'
include { BCFTOOLS_VIEW           } from '../modules/nf-core/bcftools/view/main'
include { EXOMISER                } from '../modules/local/exomiser'
include { SPLIT_MULTIALLELICS     } from '../modules/local/split_multiallelics/main'
include { VCF_ANNOTATE_ENSEMBLVEP } from '../subworkflows/nf-core/vcf_annotate_ensemblvep/main'
include { COMBINEGVCFS            } from '../modules/local/combine_gvcfs'
include { GATK4_GENOTYPEGVCFS     } from '../modules/nf-core/gatk4/genotypegvcfs'
include { GATK4_VARIANTFILTRATION } from '../modules/nf-core/gatk4/variantfiltration'
include { ENSEMBLVEP_DOWNLOAD     } from '../modules/nf-core/ensemblvep/download/main'
include { CHANNEL_CREATE_CSV as CHANNEL_CREATE_CSV_VEP      } from '../subworkflows/local/channel_create_csv'
include { CHANNEL_CREATE_CSV as CHANNEL_CREATE_CSV_GENOTYPE } from '../subworkflows/local/channel_create_csv'
include { CHANNEL_CREATE_CSV as CHANNEL_CREATE_CSV_EXOMISER } from '../subworkflows/local/channel_create_csv'
//functions
include { isExomiserToolIncluded  } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'
include { isVepToolIncluded       } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'
include { isToolIncluded          } from '../subworkflows/local/utils_nfcore_postprocessing_pipeline/utils'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PIPELINE-LOCAL PROCESS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process writemeta {

    publishDir "${params.outdir}/pipeline_info/", mode: 'copy', overwrite: 'true'
    output:
    path("metadata.txt")

    script:
    """
    cat <<EOF > metadata.txt
    Work Dir : ${workflow.workDir}
    UserName : ${workflow.userName}
    ConfigFiles : ${workflow.configFiles}
    Container : ${workflow.container}
    Start date : ${workflow.start}
    Command Line : ${workflow.commandLine}
    Revision : ${workflow.revision}
    CommitId : ${workflow.commitId}
    """

    stub:
    """
    touch metadata.txt
    """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow POSTPROCESSING {

    take:
    ch_samplesheet

    main:
    //Local Temp Params
    def pathReferenceGenomeFasta        = file(params.referenceGenome + "/" + params.referenceGenomeFasta)
    def pathReferenceGenomeFai          = file(pathReferenceGenomeFasta + ".fai")
    def pathIntervalFile                = params.intervalsFile ? file(params.intervalsFile) : []
    def pathReferenceDict               = file("${params.referenceGenome}/${file(params.referenceGenomeFasta).baseName}.dict")
    def dbsnpFile                       = params.dbsnpFile ? file(params.dbsnpFile) : []
    def dbsnpFileIndex                  = params.dbsnpFileIndex ? file(params.dbsnpFileIndex) : []
    def exomiserLocalFrequencyFile      = params.exomiser_local_frequency_path ? file(params.exomiser_local_frequency_path) : []
    // Derive the index path from the local-frequency path when not explicitly provided.
    def exomiserLocalFrequencyIndexFile = params.exomiser_local_frequency_index_path
        ? file(params.exomiser_local_frequency_index_path)
        : (params.exomiser_local_frequency_path ? file("${params.exomiser_local_frequency_path}.tbi") : [])
    def slivarRegionsBed                = params.slivar_regions_bed ? file(params.slivar_regions_bed) : []
    def slivarExcludeBed                = params.slivar_exclude_bed ? file(params.slivar_exclude_bed) : []
    def gnomadGnotate                   = params.slivar_gnomad_gnotate ? file(params.slivar_gnomad_gnotate) : []
    def topmedGnotate                   = params.slivar_topmed_gnotate ? file(params.slivar_topmed_gnotate) : []
    def slivarGnotateFiles              = [gnomadGnotate, topmedGnotate].findAll{ f -> f }
    def slivarJs                        = params.slivar_js ? file(params.slivar_js) : []

    def HOMO_SAPIENS_SPECIES = "homo_sapiens"
    def cache_species        = params.download_cache_species

    // Aggregated version YAML emitted by every called subworkflow/process; flushed at the end via softwareVersionsToYAML.
    ch_versions = channel.empty()

    // Channels that may be assigned inside `if` branches and read by later branches.
    // Declaring them up-front makes the data-flow explicit and avoids "leaks into workflow scope".
    ch_output_from_tagArtifacts       = channel.empty()
    ch_output_from_splitMultiAllelics = channel.empty()
    ch_output_from_vep                = channel.empty()

    channel
        .fromList(workflow.configFiles)
        .collectFile(storeDir: "${params.outdir}/pipeline_info/configs", cache: false)

    writemeta()

    if (params.step == 'genotype') {

        //Standardize input VCFs: locate tbi if present, run BCFTOOLS_VIEW to normalize format/extension
        ch_view_input = ch_samplesheet.map{ meta, vcf ->
            def tbi = file(vcf + ".tbi")
            [meta, vcf, tbi.exists() ? tbi : []]
        }
        BCFTOOLS_VIEW(ch_view_input, [], [], [])
        ch_versions = ch_versions.mix(BCFTOOLS_VIEW.out.versions)
        ch_vcf_tbi_standardized = BCFTOOLS_VIEW.out.vcf.join(BCFTOOLS_VIEW.out.tbi)

        //Optionally drop MNPs
        if (params.exclude_mnps) {
            ch_input_excludemnps = ch_vcf_tbi_standardized.map{ meta, vcf, _tbi -> [meta, vcf] }
            EXCLUDE_MNPS(ch_input_excludemnps, [[id: 'reference'], pathReferenceGenomeFasta])
            ch_versions = ch_versions.mix(EXCLUDE_MNPS.out.versions)
            ch_output_from_handle_mnps = EXCLUDE_MNPS.out.vcf_tbi
        } else {
            ch_output_from_handle_mnps = ch_vcf_tbi_standardized
        }

        ch_grouped_by_family = ch_output_from_handle_mnps
            //Attach a familyId groupKey so groupTuple knows when each family is complete
            .map{ meta, vcf, tbi -> tuple(groupKey(meta.familyId, meta.sampleSize), meta, vcf, tbi) }
            .groupTuple()
            .map{ _familyId, meta, vcf, tbi ->
                //now that samples are grouped together, we no longer follow sample in meta, and the id no longer needs the sampleId
                def updated_meta = meta[0].findAll{ entry -> !["sample", "id"].contains(entry.key) }
                updated_meta["id"] = updated_meta.familyId
                [updated_meta, vcf.flatten(), tbi.flatten()]
            }
            //Combine per-sample gVCF files into a multi-sample gVCF file (only for families with >1 sample)
            .branch{ meta, vcf, tbi ->
            solo: meta.sampleSize == 1
                return [meta, vcf, tbi]
            family:  meta.sampleSize  > 1
                return [meta, vcf, tbi]
        }
        
        COMBINEGVCFS(ch_grouped_by_family.family, pathReferenceGenomeFasta, pathReferenceGenomeFai, pathReferenceDict, pathIntervalFile)
        ch_versions = ch_versions.mix(COMBINEGVCFS.out.versions)
        ch_output_from_combinegvcf = COMBINEGVCFS.out.combined_gvcf
            .join(COMBINEGVCFS.out.tbi)
            .mix(ch_grouped_by_family.solo)

        //Perform joint genotyping on one or more samples
        ch_input_for_genotypegvcf = ch_output_from_combinegvcf.map{ meta, vcf, tbi -> [meta, vcf, tbi, pathIntervalFile, []] }
        GATK4_GENOTYPEGVCFS(
            ch_input_for_genotypegvcf,
            [[id: 'reference'], pathReferenceGenomeFasta],
            [[id: 'reference'], pathReferenceGenomeFai],
            [[id: 'reference'], pathReferenceDict],
            [[id: 'dbsnp'],     dbsnpFile],
            [[id: 'dbsnp_idx'], dbsnpFileIndex]
        )
        ch_versions = ch_versions.mix(GATK4_GENOTYPEGVCFS.out.versions)
        ch_output_from_genotypegvcf = GATK4_GENOTYPEGVCFS.out.vcf.join(GATK4_GENOTYPEGVCFS.out.tbi)

        //Tag variants that are probable artifacts.
        //WGS data goes through VQSR; WES data is hard-filtered via GATK4_VARIANTFILTRATION.
        ch_by_seqtype = ch_output_from_genotypegvcf.branch{ meta, vcf, tbi ->
            wgs: meta.sequencingType == "WGS"
                return [meta, vcf, tbi]
            wes: meta.sequencingType == "WES"
                return [meta, vcf, tbi]
        }

        // Expand the user-facing VQSR resource maps into the three flat channels the subworkflow expects.
        // VCF and index paths are resolved against params.broad.
        def snpResources   = params.vqsr_snp_resources
        def indelResources = params.vqsr_indel_resources

        ch_snp_resource_vcfs     = snpResources.collect{ r -> file("${params.broad}/${r.vcf}") }
        ch_snp_resource_tbis     = snpResources.collect{ r -> file("${params.broad}/${r.index}") }
        ch_snp_resource_labels   = snpResources.collect{ r -> "--resource:${r.labels} ${file(r.vcf).getFileName()}".toString() }
        ch_indel_resource_vcfs   = indelResources.collect{ r -> file("${params.broad}/${r.vcf}") }
        ch_indel_resource_tbis   = indelResources.collect{ r -> file("${params.broad}/${r.index}") }
        ch_indel_resource_labels = indelResources.collect{ r -> "--resource:${r.labels} ${file(r.vcf).getFileName()}".toString() }

        VQSR(
            ch_by_seqtype.wgs,
            ch_snp_resource_vcfs,
            ch_snp_resource_tbis,
            ch_snp_resource_labels,
            ch_indel_resource_vcfs,
            ch_indel_resource_tbis,
            ch_indel_resource_labels,
            pathReferenceGenomeFasta,
            pathReferenceGenomeFai,
            pathReferenceDict
        )
        ch_versions = ch_versions.mix(VQSR.out.versions)

        GATK4_VARIANTFILTRATION(
            ch_by_seqtype.wes,
            [[id: 'reference'], pathReferenceGenomeFasta],
            [[id: 'reference'], pathReferenceGenomeFai],
            [[id: 'reference'], pathReferenceDict]
        )
        ch_versions = ch_versions.mix(GATK4_VARIANTFILTRATION.out.versions)
        ch_variantfiltration_output = GATK4_VARIANTFILTRATION.out.vcf
            .join(GATK4_VARIANTFILTRATION.out.tbi)

        ch_output_from_tagArtifacts = VQSR.out.vcf_tbi.mix(ch_variantfiltration_output)
    }

    if (params.step in ['genotype', 'normalize']) {
        vcf_for_norm = params.step == 'genotype'
            ? ch_output_from_tagArtifacts
            : ch_samplesheet // ch_samplesheet will be the csv retrieved from outdir

        //normalize variants
        SPLIT_MULTIALLELICS(vcf_for_norm, [[id: 'reference'], pathReferenceGenomeFasta])
        ch_versions = ch_versions.mix(SPLIT_MULTIALLELICS.out.versions)
        ch_output_from_splitMultiAllelics = SPLIT_MULTIALLELICS.out.vcf.join(SPLIT_MULTIALLELICS.out.tbi)

        if (params.save_genotyped || !params.tools) {
            CHANNEL_CREATE_CSV_GENOTYPE(ch_output_from_splitMultiAllelics, "normalized_genotypes", params.outdir, [])
        }
    }

    if ((params.step in ['genotype', 'normalize'] && isVepToolIncluded()) || params.step == 'annotation') {

        //Annotating variants with VEP

        // Download VEP cache if download = true. Assuming we want to download even if cache provided.
        if (params.download_cache) {
            ensemblvep_info = channel.of([ [ id: "${params.vep_cache_version}_${params.vep_genome}" ], params.vep_genome, cache_species, params.vep_cache_version ])
            ENSEMBLVEP_DOWNLOAD(ensemblvep_info)
            vep_cache = ENSEMBLVEP_DOWNLOAD.out.cache.collect().map{ _meta, cache -> [ cache ] }.first()
            ch_versions = ch_versions.mix(ENSEMBLVEP_DOWNLOAD.out.versions.first())
        } else {
            vep_cache = file(params.vep_cache)
        }

        vcf_for_vep = params.step in ['genotype', 'normalize']
            ? ch_output_from_splitMultiAllelics
            : ch_samplesheet // ch_samplesheet will be the csv retrieved from outdir

        VCF_ANNOTATE_ENSEMBLVEP(
            vcf_for_vep.map{ meta, vcf, _tbi -> [meta, vcf, []] },  // meta, vcf, optional_custom_files
            [[id: 'reference'], pathReferenceGenomeFasta],                        // meta2, fasta
            params.vep_genome,
            HOMO_SAPIENS_SPECIES,
            params.vep_cache_version,
            vep_cache,
            []                                                       // extra files
        )
        ch_versions = ch_versions.mix(VCF_ANNOTATE_ENSEMBLVEP.out.versions)
        ch_output_from_vep = VCF_ANNOTATE_ENSEMBLVEP.out.vcf_tbi

        CHANNEL_CREATE_CSV_VEP(ch_output_from_vep, "ensemblvep", params.outdir, params.vep_outdir ?: [])
    }

    if (isToolIncluded('slivar') || params.step == 'inheritance') {
        if (params.step == 'inheritance') {
            log.info("Step 'inheritance': assuming input VCF is already VEP-annotated")
            ch_vcf_slivar = ch_samplesheet
        } else {
            ch_vcf_slivar = ch_output_from_vep
        }

        ch_slivar_input = ch_vcf_slivar
            .filter{ meta, _vcf, _tbi -> meta.familyPed }
            .map{ meta, vcf, tbi -> [meta, vcf, tbi, meta.familyPed] }

        SLIVAR_INHERITANCE(ch_slivar_input, slivarRegionsBed, slivarExcludeBed, slivarGnotateFiles, slivarJs)
    }

    if (isExomiserToolIncluded() || params.step == 'exomiser') {

        if (params.exomiser_start_from_vep) {
            log.info("Running the exomiser analysis using the vep annotated vcf file as input")
            ch_exomiser_input = params.step == 'exomiser' ? ch_samplesheet : ch_output_from_vep
        } else {
            ch_exomiser_input = params.step == 'exomiser' ? ch_samplesheet : ch_output_from_splitMultiAllelics
        }

        def remm_input = params.exomiser_remm_version
            ? [params.exomiser_remm_version, params.exomiser_remm_filename]
            : ["", ""]
        def cadd_input = params.exomiser_cadd_version
            ? [params.exomiser_cadd_version, params.exomiser_cadd_snv_filename, params.exomiser_cadd_indel_filename]
            : ["", "", ""]

        // Keep only families that supplied a phenopacket; attach the right analysis YAML per sequencing type.
        ch_input_for_exomiser = ch_exomiser_input
            .filter{ meta, _vcf, _tbi -> meta.familyPheno }
            .map{ meta, vcf, tbi -> [
                meta,
                vcf,
                tbi,
                meta.familyPheno,
                meta.sequencingType == "WES" ? file(params.exomiser_analysis_wes) : file(params.exomiser_analysis_wgs)
            ]}

        EXOMISER(
            ch_input_for_exomiser,
            file(params.exomiser_data_dir),
            params.exomiser_genome,
            params.exomiser_data_version,
            [exomiserLocalFrequencyFile, exomiserLocalFrequencyIndexFile],
            remm_input,
            cadd_input
        )
        ch_versions = ch_versions.mix(EXOMISER.out.versions)

        CHANNEL_CREATE_CSV_EXOMISER(
            EXOMISER.out.vcf.join(EXOMISER.out.tbi, failOnDuplicate: true, failOnMismatch: true),
            "exomiser",
            params.outdir,
            params.exomiser_outdir ?: []
        )
    }

    // Collate and write the aggregated software versions for MultiQC.
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:     'Post-Processing-Pipeline_software_mqc_versions.yml',
            sort:     true,
            newLine:  true
        )

    emit:
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
