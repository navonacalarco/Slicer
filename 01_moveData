
#This script is used to move data from the archive/data/ folders, to my own
#Note: I am using outputs from dmriprep, the 'in-house' DWI preprocessing pipeline


#move to SPINS dmriprep outputs in lab archive
cd /archive/data/SPINS/pipelines/bids_apps
#For the most recent run, I have taken files from /scratch/mjoseph/bids/SPINS/derivatives/dmriprep_new

#copy all dmriprep directories over to my own
cp -r dmriprep /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep
#cp -r /scratch/mjoseph/bids/SPINS/derivatives/dmriprep_new/sub-* /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep

#also make a copy of the QC folder -- need to QC
cp /scratch/mjoseph/bids/SPINS/derivatives/dmriprep_new/QC /projects/ncalarco/thesis/SPINS/Slicer/QC

#if desired, find all directories of phantoms and tests that should delete
#however,, I will just run on everything, incase we want to test something on a non-participant
cd /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep
find . -type d \( -name "*PHA" -o -name "*P00" -o -name "*999" -o -name "*998" \)
#rm -r found files

############################################################################

#count how many directories exist
ls | wc -l #468 

#write out the subject names with data
ls > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/01_hasData.txt

#are any of these directories empty?
cd /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep
find . -mindepth 3 -type d -empty #none are empty

#count participants that have eddy -- 475 (so, some participants has session 2 data)
find /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/*/*/dwi/ -name '*desc-eddy_dwi.nii.gz' | wc -l

#count participants that have brainsuite - 475
find /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/*/*/dwi/ -name '*desc-brainsuite_dwi.nii.gz' | wc -l

#write out these lists
find /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/*/*/dwi/ -name '*desc-eddy_dwi.nii.gz' > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/01_hasEddy.txt
find /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/*/*/dwi/ -name '*desc-brainsuite_dwi.nii.gz' > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/01_hasBrainsuite.txt

#in R, figure out which subjects are missing, and why...
#"sub-ZHP0063" 
#"sub-ZHP0082" 
#"sub-ZHP0125" 
#"sub-ZHP0165"

#Michael informs that these 5 subjects had bad FreeSurfer (CMP0198, ZHP0063, ZHP0082, ZHP0125, ZHP0165) - will be re-run

#remove folders from participants with no data
#rm -r /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/{CMP0198,sub-ZHP0063,sub-ZHP0082,sub-ZHP0125,sub-ZHP0165} #replace 'sub' with real subject IDs


