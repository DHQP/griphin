/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

/*
========================================================================================
    IMPORT LOCAL MODULES
========================================================================================
*/

include { GRIPHIN            } from '../modules/local/griphin'
include { CREATE_SAMPLESHEET } from '../modules/local/create_samplesheet'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

workflow GRIPHIN_WF {
    main:
        ch_versions = Channel.empty()
        // Allow outdir to be relative
        //outdir_path = Channel.fromPath(params.outdir, relative: true, type: 'dir')

        // Check input path parameters to see if they exist
        if (params.input != null ) {  // if a samplesheet is passed
            // allow input to be relative, turn into string and strip off the everything after the last backslash to have remainder of as the full path to the samplesheet. 
            //input_samplesheet_path = Channel.fromPath(params.input, relative: true).map{ [it.toString().replaceAll(/([^\/]+$)/, "").replaceAll(/\/$/, "") ] }
            input_samplesheet_path = Channel.fromPath(params.input, relative: true)
            if (params.input_dir != null ) { //if samplesheet is passed and an input directory exit
                exit 1, 'You need EITHER an input samplesheet or a directory! Just pick one.' 
            } else { // if only samplesheet is passed check to make sure input is an actual file
                def checkPathParamList = [ params.input ]
                for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
            }
        } else {
            if (params.input_dir != null ) { // if no samplesheet is passed, but an input directory is given
                def checkPathParamList = [ params.input_dir ]
                for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
            } else { // if no samplesheet is passed and no input directory is given
                exit 1, 'You need EITHER an input samplesheet or a directory!' 
            }
        }

        if (params.input != null) {
            if (params.control_list != null){
                // Allow control list to be relative
                control_path = Channel.fromPath(params.control_list, relative: true)
                // Create report
                GRIPHIN (
                    input_samplesheet_path, params.ardb, params.prefix, control_path, [], params.platform
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            } else {
                // Create report
                GRIPHIN (
                    input_samplesheet_path, params.ardb, params.prefix, [], [], params.platform
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            }
        } else {
            // allow input directory to be relative
            inputdir_path = Channel.fromPath(params.input_dir, relative: true, type: 'dir') // this same path is needed to make the samplesheet

            // Create samplesheet
            CREATE_SAMPLESHEET (
                inputdir_path
            )

            if (params.control_list != null){
                // Allow control list to be relative
                control_path = Channel.fromPath(params.control_list, relative: true)
                // Create report
                GRIPHIN (
                    CREATE_SAMPLESHEET.out.samplesheet, params.ardb, params.prefix, control_path, inputdir_path, params.platform
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            } else {
                // Create report
                GRIPHIN (
                    CREATE_SAMPLESHEET.out.samplesheet, params.ardb, params.prefix, [], inputdir_path, params.platform
                )
                ch_versions = ch_versions.mix(GRIPHIN.out.versions)
            }
        }

        CUSTOM_DUMPSOFTWAREVERSIONS (
            ch_versions.unique().collectFile(name: 'collated_versions.yml')
        )

    emit:
        griphin_report = GRIPHIN.out.griphin_report

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
