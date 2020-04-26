#!/bin/bash -l

####################################################################################
#Name:         06_makeVTK.sh

#Last updated: 2020-04-28

#Description:  Fits a tensor, makes a mask, and performs tractography

#Submission:   sbatch

#Notes: 
               #For sbatch, remember to change the array to reflect number of participants
               #These commands are part of SlicerDMRI proper (cf. white matter analysis) 
####################################################################################

#SBATCH --partition=high-moby
#SBATCH --array=1-454
#SBATCH --nodes=1
#SBATCH --time=20:00
#SBATCH --export=ALL
#SBATCH --job-name=Slicer
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.out
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.err
#SBATCH --mem-per-cpu=1G

cd $SLURM_SUBMIT_DIR

sublist="/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt"

index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \
   | tail -n 1
}

#load modules
module load python/2.7.9-anaconda-2.1.0-150119
module load slicer/4.8.1
module load DTIPrep/1.2.8

#set up directories
inputdir='/projects/ncalarco/thesis/SPINS/Slicer/data/04_nrrd'
dtiprep_protocol='/projects/ncalarco/thesis/SPINS/Slicer/data/05_dtiprep_protocols'
outputdir='/projects/ncalarco/thesis/SPINS/Slicer/data/06_vtk'

#export environment variables
export inputimage="${inputdir}/`index`*.nrrd"
export stem="$(basename $inputimage .nrrd)"
export output_name="${outputdir}/${stem}"

####################################################################################
#STEP 1: FIT THE TENSOR
####################################################################################

#Description:   Perform diffusion tensor estimation
#GUI analogue:  Modules > Diffusion > Process > Diffusion Tensor Estimation
#Documentation: https://www.slicer.org/wiki/Documentation/Nightly/Modules/DWIToDTIEstimation

Slicer --launch DWIToDTIEstimation \
  --inputVolume ${inputimage} \                      #input raw DWI (must be .nrrd, no floats)
  --outputTensor ${output_name}_DTI.nrrd \           #estimated DTI volume
  --outputBaseline ${output_name}_SCALAR.nrrd \      #estimated baseline (non-DW) volume (i.e., the b0)
  --enumeration WLS \                                #weighted least squares
  --shiftNeg
                                   
#DEFAULT PARAMETERS: 
#shiftNeg: false    If true, shift negative eigenvalues so that all are positive: this accounts for unuseable tensor solutions related to noise or acquisition error

####################################################################################
#STEP 2: MAKE A MASK
####################################################################################
 
#Description:   Make a mask within Slicer for tractography seeding (required for whole brain)
#GUI analogue:  Modules > Diffusion > Process > Diffusion Brain Masking
#Documentation: https://www.slicer.org/wiki/Documentation/Nightly/Modules/DiffusionWeightedVolumeMasking

Slicer --launch DiffusionWeightedVolumeMasking \
  --inputVolume ${inputimage} \
  --outputBaseline ${output_name}_SCALAR.nrrd \
  --thresholdMask ${output_name}_MASK.nrrd \
  --removeislands

#DEFAULT PARAMETERS: 
#remoteislands: true            Removes disconnected regions from brain mask
#baselineBValueThreshold: 100   Volumes with B-value below this threshold will be considered baseline images and included in mask calculation

####################################################################################
#STEP 3: WHOLE BRAIN TRACTOGRAPHY
####################################################################################

#Description:   Whole brain tractography via label map seeding
#GUI analogue:  Modules > Tractography Seeding
#Documentation: https://www.slicer.org/wiki/Documentation/Nightly/Modules/TractographyLabelMapSeeding

Slicer --launch TractographyLabelMapSeeding \
  ${output_name}_DTI.nrrd \                                   #DTI volume in which to generate tractography
  --inputroi ${output_name}_MASK.nrrd \                       #label map defining region for seeding tractography (i.e., the mask)
  --OutputFibers ${output_name}_SlicerTractography.vtk \      #name of tractography result
  --stoppingvalue 0.10 \                                       #tractography will stop when measurements drop below this value: note default is .25
  --useindexspace 

#DEFAULT PARAMETERS
#start threhold: .3                 Minimum Linear Measure for the seeding to start
#minimum length: 20                 Minimum length of the fibers (in mm)
#maximum length: 800                Maximum length of fibers (in mm)
#thresholdmode: FA                  Tensor measurement used to start and stop the tractography
#stopping curvature: .7             Tractography will stop if radius of curvature becomes smaller than this number units are degrees per mm
#integration step length: .5        Distance between points on the same fiber in mm
#use index space: true              Seed at the IJK voxel

####################################################################################
  
#once this script has run, for ease, move over just the tractography files to a separate (flat) directory
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/07_vtkTractsOnly
find . -name '*_SlicerTractography.vtk' -exec mv -t ../07_vtkTractsOnly/ {} +

#make sure all data made it through
ls /projects/ncalarco/thesis/SPINS/Slicer/data/07_vtkTractsOnly | wc #449
