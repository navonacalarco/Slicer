#!/bin/bash

####################################################################################
#Name:         #02_dwiQC.sh

#Last updated: #2020-03-17

#Description:  
               #This script checks the automated QC results produced by dwiprep. Even though 
               #I am using preprocessed outputs from dmriprep (in-house pipeline), the 
               #automated dwiprep QC outputs remain useful. Specifically, we check for the 
               #3 PASS results at the end of each participant's `*_QCReport.txt` file. All 
               #participants that PASS are included in subsequent analyses

#Submission:   #Run as bash or interactively in terminal

#Notes:        #If it exists, make sure to remove the `participants.csv` file that has been 
               #added in the archive, from 02_dwiprepQC_automatedFAILS.txt and 03_sublist.txt
####################################################################################

#move to dtiprep directory
cd /archive/data/SPINS/pipelines/dtiprep

#identify participants with 'fail' in the last 3 lines of dwiprep report
for file in ./*/*QCReport.txt
  do count="$echo `tail -3 $file | grep -i "FAIL" | wc -l`"
    if [[ "$count" -ne 0 ]]
      then echo "This participant has failed automated dwiprep QC: $file"
    fi
done > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/02_dwiprepQC_automatedFAILS.txt

#if required, remove data from failed participants 
#rm -r /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/{...} #update subject IDs as required

#write out included participants list
ls /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt	

