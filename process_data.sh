#!/bin/bash
#
# Preprocess data.
#
# Dependencies (versions):
# - SCT (6.2)
#
# Usage:
# sct_run_batch -script preprocess_data.sh -path-data <PATH-TO-DATASET> -path-output <PATH-TO-OUTPUT> -jobs <num-cpu-cores>

# Manual segmentations or labels should be located under:
# PATH_DATA/derivatives/labels/SUBJECT/ses-0X/anat/

# The following global variables are retrieved from the caller sct_run_batch
# but could be overwritten by uncommenting the lines below:
# PATH_DATA_PROCESSED="~/data_processed"
# PATH_RESULTS="~/results"
# PATH_LOG="~/log"
# PATH_QC="~/qc"


# Uncomment for full verbose
set -x

# Immediately exit if error
set -e -o pipefail

# Exit if user presses CTRL+C (Linux) or CMD+C (OSX)
trap "echo Caught Keyboard Interrupt within script. Exiting now.; exit" INT


# FUNCTIONS
# ======================================================================================================================

segment_if_does_not_exist() {
  ###
  local file="$1"
  local contrast="$2"
  # Update global variable with segmentation file name
  FILESEG="${file}_seg"
  FILESEGJSON="${PATH_DATA_PROCESSED}/derivatives/${SUBJECT}/anat/${FILESEG}.json"
  FILESEGMANUAL="${PATH_DATA_PROCESSED}/derivatives/${SUBJECT}/anat/${FILESEG}-manual.nii.gz"
  FILE_OUTPUT="${PATH_DATA_PROCESSED}/derivatives/${SUBJECT}/anat/${FILESEG}.nii.gz"
  echo
  echo "Looking for manual segmentation: $FILESEGMANUAL"
  if [[ -e $FILESEGMANUAL ]]; then
    echo "Found! Using manual segmentation."
  else
    echo "Not found. Proceeding with automatic segmentation."
    sct_deepseg_sc -i ${file}_T2starw.nii.gz -c $contrast -o $FILE_OUTPUT -qc ${PATH_QC} -qc-subject ${SUBJECT}

    SCT_VERSION=$(sct_version)
    SCT_DATE=$(date)
    SCT_USER=$(whoami)
  
    json_string='{ "sct_version": "'"${SCT_VERSION}"'", "date": "'"${SCT_DATE}"'", "Username": "'"$SCT_USER"'" }'
    echo "$json_string" > ${FILESEGJSON}
  fi
}


segment_gm_if_does_not_exist() {
  ###
  local file="$1"
  # Update global variable with segmentation file name
  FILESEG="${file}_gmseg"
  FILESEGJSON="${PATH_DATA_PROCESSED}/derivatives/${SUBJECT}/anat/${FILESEG}.json"
  FILESEGMANUAL="${PATH_DATA_PROCESSED}/derivatives/${SUBJECT}/anat/${FILESEG}-manual.nii.gz"
  FILE_OUTPUT="${PATH_DATA_PROCESSED}/derivatives/${SUBJECT}/anat/${FILESEG}.nii.gz"
  echo
  echo "Looking for manual segmentation: $FILESEGMANUAL"
  if [[ -e $FILESEGMANUAL ]]; then
    echo "Found! Using manual segmentation."
  else
    echo "Not found. Proceeding with automatic segmentation."
    sct_deepseg_gm -i ${file}_T2starw.nii.gz -o $FILE_OUTPUT -qc ${PATH_QC} -qc-subject ${SUBJECT}

    SCT_VERSION=$(sct_version)
    SCT_DATE=$(date)
    SCT_USER=$(whoami)
  
    json_string='{ "sct_version": "'"${SCT_VERSION}"'", "date": "'"${SCT_DATE}"'", "Username": "'"$SCT_USER"'" }'
    echo "$json_string" > ${FILESEGJSON}
  fi
}



# Retrieve input params and other params
SUBJECT=$1

# get starting time:
start=`date +%s`


# SCRIPT STARTS HERE
# ==============================================================================
# Display useful info for the log, such as SCT version, RAM and CPU cores available
sct_check_dependencies -short

# Go to folder where data will be copied and processed
cd $PATH_DATA_PROCESSED

if  [[ ! -f "participants.tsv" ]]; then
    rsync -avzh $PATH_DATA/participants.tsv .
fi

rsync -Ravzh $PATH_DATA/./$SUBJECT .

# Make derivatives directory for output
mkdir -p derivatives/${SUBJECT}/anat

# Go to subject folder for source images
cd ${SUBJECT}/anat

# Define variables
# We do a substitution '/' --> '_' in case there is a subfolder 'ses-0X/'
file="${SUBJECT//[\/]/_}"

#Loop through the different acquisition and reconstruction options
ACQ=("acq-upperT" "acq-lowerT" "acq-LSE")
REC=("rec-navigated" "rec-standard")

for acq in "${ACQ[@]}";do
    for rec in "${REC[@]}";do
        file_input=${file}_${acq}_${rec}
        if [ -e "${file_input}_T2starw.nii.gz" ]; then
             echo "Processing"
             segment_if_does_not_exist ${file_input} t2s
             segment_gm_if_does_not_exist ${file_input}

	    

        else
             echo "Skipping - file not found"
        fi
    done
done





# Display useful info for the log
end=`date +%s`
runtime=$((end-start))
echo
echo "~~~"
echo "SCT version: `sct_version`"
echo "Ran on:      `uname -nsr`"
echo "Duration:    $(($runtime / 3600))hrs $((($runtime / 60) % 60))min $(($runtime % 60))sec"
echo "~~~"