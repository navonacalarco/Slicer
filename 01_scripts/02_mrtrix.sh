#!/bin/bash

####################################################################################
#Name:         02_mrtrix.sh

#Last updated: 2020-03-17

#Description:  #Here, I run MRTRIX, for the purposes of obtaining noise residuals for 
               #each participant. These residual values indicate the amount of noise 
               #that "cannot be cleaned up from eddy" (arbitrary unit). 

#Submission:   sbatch (remember to change the array to reflect number of participants)

#Notes:        #The DWI working group decided that, in addition to the eddy QC metrics, 
               #the noise value from mrtrix is useful. 
               #First, we can visually QC these images as as index of data quality
               #Second, we will evaluate 5 select eddy metrics and this single mrtrix 
               #metric to automately flag poor scans
               #Third, we can combine the first PC of the PCA will be used as a 
               #regressor indicating data quality.
               #See https://github.com/navonacalarco/thesis .. 01_DWI_automatedQC_eddyMRTrix.Rmd
####################################################################################

#SBATCH --partition=moby
#SBATCH --array=1-475
#SBATCH --nodes=1
#SBATCH --time=20:00
#SBATCH --export=ALL
#SBATCH --job-name MRTRIX
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.out
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.err
#SBATCH --mem-per-cpu=1G

cd $SLURM_SUBMIT_DIR

subject_list="/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt"

index() {
   head -n $SLURM_ARRAY_TASK_ID $subject_list \
   | tail -n 1
}

#load modules
source /etc/profile.d/quarantine.sh
module load FSL/5.0.11
module load MRtrix3/20180123

#make a new directory for the eddy-corrected and distortion corrected data
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/input_eddy

#find and copy the data to a flat directory
find /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep -name '*_desc-brainsuite_dwi.nii.gz' -exec cp -t ../02_mrtrix_QC/input_eddy {} +

#set up directory variables
indir="/projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/input_eddy"
outdir="/projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/output_mrtrixResiduals"
noisedir="/projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/output_mrtrixNoise"

#make output directory if doesn't exist
mkdir -p ${outdir}
mkdir -p ${noisedir}

#make the script tell us what participant it's on while it runs MRTRIX
echo `index`
if [ ! -e ${outdir}/`index`_sphericalResidualNoise.nii.gz ]
then

    #run dwidenoise (produces an image from which we can extract noise)
    dwidenoise -noise ${noisedir}/`index`_noise.nii.gz ${indir}/`index`_*desc-brainsuite_dwi.nii.gz ${outdir}/`index`_sphericalResiduals.nii.gz

else
    echo `index` "already has a MRTRIX noise.nii"
fi

#remove the NANs from the image, and overwrite
fslmaths ${noisedir}/`index`_noise.nii.gz -nan ${noisedir}/`index`_noise.nii.gz

#write out the file, and also add the noise value to a text file
echo "$(fslstats ${noisedir}/`index`_noise.nii.gz -M) `index`" >> /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/04_mrtrix_residualNoise.txt
