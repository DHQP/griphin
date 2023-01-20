//
// Subworkflow: one of the workflows to generate a report
//

include { CREATE_FASTP_DF                               } from '../../modules/local/spades'

workflow GRIPHIN_WORKFLOW {
    take:
        paired_reads_json // channel: tuple val(meta), path('*.json'): FASTP_TRIMD.out.json --> PHOENIX_EXQC.out.paired_trmd_json
        phoenix_report    // channel: path(paired_report)            : GATHER_SUMMARY_LINES.out.summary_report --> PHOENIX_EXQC.out.summary_report

    main:
        ch_versions     = Channel.empty() // Used to collect the software versions

        // Combining paired end reads and unpaired reads that pass QC filters, both get passed to Spades
        passing_reads_ch = paired_reads.map{ meta, reads          -> [[id:meta.id],reads]}\
        .join(single_reads.map{              meta, reads          -> [[id:meta.id],reads]},          by: [0])\
        .join(k2_bh_summary.map{             meta, ksummary       -> [[id:meta.id],ksummary]},       by: [0])\
        .join(fastp_raw_qc.map{              meta, fastp_raw_qc   -> [[id:meta.id],fastp_raw_qc]},   by: [0])\
        .join(fastp_total_qc.map{            meta, fastp_total_qc -> [[id:meta.id],fastp_total_qc]}, by: [0])\
        .join(report.map{                    meta, report         -> [[id:meta.id],report]},         by: [0])\
        .join(krona_html.map{                meta, krona_html     -> [[id:meta.id],krona_html]},     by: [0])

        // Assemblying into scaffolds by passing filtered paired in reads and unpaired reads
        SPADES (
            passing_reads_ch
        )
        ch_versions = ch_versions.mix(SPADES.out.versions)

        if (report == "ar_report") { // 
            //Gather all fastp output
            fastp_json_ch = paired_reads_json.collect()

            // MODULE: Run FastQC
            CREATE_FASTP_DF (
                INPUT_CHECK.out.reads
            )
                    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

        } else if(report =="oa_report") {
        
        }
        
        } else {

        }

        // Create one line summary for case when spades fails to create scaffolds
        CREATE_SUMMARY_LINE_FAILURE (
            line_summary_ch
        )

    emit:
        versions                    = ch_versions // channel: [ versions.yml ]
}