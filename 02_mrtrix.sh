#!/bin/bash

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

#Submit to slurm with sbatch
#Need to check that the number associated with the array in the header is the exact number of participant!


#Before running on Slurm, can test the script by setting the index to one participant:
#index() {
#   head -n 1 $subject_list \
#   | tail -n 1
#}

## source /etc/profile.d/modules.sh This doesn’t exist anymore -- Kevin
source /etc/profile.d/quarantine.sh
module load FSL/5.0.11
module load MRtrix3/20180123

#In this script, I run MRTRIX, for the purposes of obtaining noise residuals for each participant, which will be used in the QC process.
#These residual values indicate the amount of noise that "cannot be cleaned up from eddy". It is an arbitrary unit.
#It will provide a single average colume, which is the average of a 3D volume
#The DWI working group decided that, in addition to the eddy QC metrics, the noise value from mrtrix is useful
#Ultimately, the 5 eddy metrics and the single mrtrix metric will be combined in a PCA
#Before deciding to use, I should make sure that the noise value correlates as expected with all eddy metrics
#The first PC of the PCA will be used as a regressor indicating data quality

#make a new directory for the eddy-corrected and distortion corrected data
#mkdir /projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/input_eddy

#find and move the data (easier to have in a single place)
#find /projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep -name '*_desc-brainsuite_dwi.nii.gz' -exec cp -t ../02_mrtrix_QC/input_eddy {} +

#Now, set up input and output for MRTRIX
indir="/projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/input_eddy"
outdir="/projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/output_mrtrixResiduals"
noisedir="/projects/ncalarco/thesis/SPINS/Slicer/data/02_mrtrix_QC/output_mrtrixNoise"

#make output directory if doesn't exist
mkdir -p ${outdir}
mkdir -p ${noisedir}

#Make the script tell us what participant it's on while it runs MRTRIX
echo `index`
if [ ! -e ${outdir}/`index`_sphericalResidualNoise.nii.gz ]
then

    #Now, run dwidenoise, which produces an image from which we can extract noise
    dwidenoise -noise ${noisedir}/`index`_noise.nii.gz ${indir}/`index`_*desc-brainsuite_dwi.nii.gz ${outdir}/`index`_sphericalResiduals.nii.gz

else
    echo `index` "already has a MRTRIX noise.nii"
fi


#Remove the NANs from the image, and overwrite
fslmaths ${noisedir}/`index`_noise.nii.gz -nan ${noisedir}/`index`_noise.nii.gz

#Write out the file, and add the noise value to a text file
echo "$(fslstats ${noisedir}/`index`_noise.nii.gz -M) `index`" >> /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/04_mrtrix_residualNoise.txt

#The MRTRIX residuals are of interest to us for 2 reasons:
#1. We can QC the residual images
#2. In R, will combine this value with QC metrics from eddy, and run a PCA and extra the first component. This will be used as a covariate in analyses.
#https://github.com/navonacalarco/thesis/tree/master/SPINS/analyses/01_imagingQC/scripts
#https://rpubs.com/navona/SPINS_DWI_QCautomated
