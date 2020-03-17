#This script checks the automated QC results produced by dwiprep (part of preprocessing). 
#I am using preprocessing from dmriprep, i.e., the lab's own pipeline (new)
#However, it is still useful to review the automated dwiprep outputs

#Specifically, we check for the 3 PASS results at the end of each `*_QCReport.txt` file.

#make sure in correct directory
cd /archive/data/SPINS/pipelines/dtiprep

#identify participants with 'fail' in the last 3 lines of dwiprep report
for file in ./*/*QCReport.txt
  do count="$echo `tail -3 $file | grep -i "FAIL" | wc -l`"
    if [[ "$count" -ne 0 ]]
      then echo "This participant has failed automated dwiprep QC: $file"
    fi
done > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/02_dwiprepQC_automatedFAILS.txt

#if required, remove data from participants from out data - in our case, just the non-human phantoms have failed, as is expected

#when satisfied, output subjects list
ls /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt	

#if it exists, also make sure to remove the `participants.csv` file that has been added in the archive, from both the data, and 03_sublist.txt
