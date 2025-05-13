/**
CHANNEL CREATE CSV
    This subworkflow creates a CSV file from the input channel. 
    The CSV file contains the header and the paths of the files.
*/

workflow CHANNEL_CREATE_CSV {

    take:
    ch_input // channel: [ val(meta), [ bam, bai] ]
    tool    // val(tool) - tool name, must match the name of the tool's output dir
    outdir  // params.outdir - output directory

    main:

    def dir = "${outdir}/${tool}"

    ch_input.map { channel -> 
        def meta = channel[0].collectEntries { k, v ->
                    [ k, v instanceof Path ? v.toUriString() : v]
                }  // to not loose the complete path when there are meta fields that are files. 
        def files = channel[1..-1]
        [meta, files]
        }
        .collectFile(keepHeader: true, skip: 1, sort: true, storeDir: "${outdir}/csv") { meta, files -> 
        def header = meta.keySet().join(",")
        // generate output directory path for each file in files, check if they exist
        def files_path = files.collect { outfile ->
                            def filetype = outfile.name.replaceAll(/\.gz$/, '').tokenize('.')[-1]
                            header += ",${filetype}" // get type of file and add to header
                            return "${dir}/${outfile.name}" // return the final ouput path of the file
                        }.join(",") // if multiple files, join the paths with a comma
        ["${tool}.csv", "${header}\n${meta.values().join(",")},${files_path}\n"]
    }

}
