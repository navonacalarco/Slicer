#!/bin/bash -l

####################################################################################
#Name:         06_makeVTK.sh

#Last updated: 2020-06-08

#Description:  Fits a tensor, makes a mask, and performs tractography

#Notes:
               #These commands are part of SlicerDMRI proper (cf. white matter analysis) 
               #If running on MAC, provide entire path to given Slicer script, e.g.:
               #/Applications/Slicer.app/Contents/Extensions-28257/SlicerDMRI/lib/Slicer-4.10/cli-modules/scriptName
               #See help with scriptName -h
               #We decided to run tractography on a single computer instead of slurm
####################################################################################

#load modules
module load slicer/0,nightly

#set up directories
inputdir='/projects/ncalarco/thesis/SPINS/Slicer/data/05_nrrd'
outputdir='/projects/ncalarco/thesis/SPINS/Slicer/data/07_vtk'

#make output directory
mkdir -p ${outputdir}

####################################################################################
#STEP 1: FIT THE TENSOR
####################################################################################

#Description:   Perform diffusion tensor estimation
#GUI analogue:  Modules > Diffusion > Process > Diffusion Tensor Estimation
#Documentation: https://www.slicer.org/wiki/Documentation/Nightly/Modules/DWIToDTIEstimation
#Note:          Weighted least squares (cf. least squares) takes into account the noise characteristics of the MRI images to weight the DWI samples based on their intensity magnitude.
#               Note also that, as written, the output goes to the `06_nrrd` directory
#Time:          Lengthy

while read subject
do
Slicer --launch DWIToDTIEstimation \
  --enumeration WLS \
  --shiftNeg \
  ${inputdir}/${subject}.nrrd \
  ${inputdir}/${subject}_DTI.nrrd \
  ${inputdir}/${subject}_SCALAR.nrrd
done < /projects/ncalarco/thesis/SPINS/Slicer/outputs/03_sublist.txt
                              
#DEFAULT PARAMETERS: 
#shiftNeg: false    If true, shift negative eigenvalues so that all are positive: this accounts for unuseable tensor solutions related to noise or acquisition error
#enumeration: WLS   Weighted least squares

#-----------------------------------------------------------------------------------
#If running a test from home (MAC) on data on local computer:

#First, need to add the Slicer library to my Python path
#export PYTHONPATH=${PYTHONPATH}:/Applications/Slicer.app/Contents/Extensions-28257/SlicerDMRI/lib/Slicer-4.10/cli-modules

#Make a .txt of test subject IDs, and fit tensor:
#while read subject
#do
#   /Applications/Slicer.app/Contents/Extensions-28257/SlicerDMRI/lib/Slicer-4.10/cli-modules/DWIToDTIEstimation \
#  ${nrrd_dir}/${subject}_eddy_fixed.nrrd \
#  ${vtk_dir}/${subject}_DTI.nrrd \
#  ${vtk_dir}/${subject}_SCALAR.nrrd \
#  --enumeration WLS \
#  --shiftNeg
#done < ${base_path}/participantList.txt
#-----------------------------------------------------------------------------------

####################################################################################
#STEP 2: MAKE A MASK
####################################################################################
 
#Description:   Make a mask within Slicer for tractography seeding (required for whole brain)
#GUI analogue:  Modules > Diffusion > Process > Diffusion Brain Masking
#Documentation: https://www.slicer.org/wiki/Documentation/Nightly/Modules/DiffusionWeightedVolumeMasking
#               Note also that, as written, the output goes to the `06_nrrd` directory
#Time:          Fast

while read subject
do
Slicer --launch DiffusionWeightedVolumeMasking \
  --removeislands \
  ${inputdir}/${subject}.nrrd \
  ${inputdir}/${subject}_SCALAR.nrrd \
  ${inputdir}/${subject}_MASK.nrrd
done < /projects/ncalarco/thesis/SPINS/Slicer/outputs/03_sublist.txt


#DEFAULT PARAMETERS: 
#removeislands: true            Removes disconnected regions from brain mask
#baselineBValueThreshold: 100   Volumes with B-value below this threshold will be considered baseline images and included in mask calculation

####################################################################################
#STEP 3: WHOLE BRAIN TRACTOGRAPHY
####################################################################################

#Description:   Whole brain tractography via label map seeding
#GUI analogue:  Modules > Tractography Seeding
#Documentation: https://www.slicer.org/wiki/Documentation/Nightly/Modules/TractographyLabelMapSeeding
#               See also issue https://github.com/SlicerDMRI/SlicerDMRI/issues/129, which confirms that 
#               TractographyLabelMapSeeding (used here) in the command line and the interactive GUI module
#               should lead to same results
#Time:          Lengthy

while read subject
do
Slicer --launch TractographyLabelMapSeeding \
  ${inputdir}/${subject}_DTI.nrrd \                                   #DTI volume in which to generate tractography
  --inputroi ${inputdir}/${subject}_MASK.nrrd \                       #label map defining region for seeding tractography (i.e., the mask)
  ${outputdir}/${subject}_SlicerTractography.vtk \                     #name of tractography result
  --stoppingvalue 0.10 \                                       #tractography will stop when measurements drop below this value: note default is .25
  --useindexspace 
done < /projects/ncalarco/thesis/SPINS/Slicer/outputs/03_sublist.txt

#DEFAULT PARAMETERS
#start threhold (-clthreshold): .3                       Minimum Linear Measure for the seeding to start
#minimum length (-minimumlength): 20                     Minimum length of the fibers (in mm)
#maximum length (-maximumlength): 800                    Maximum length of fibers (in mm)
#thresholdmode: FA                                       Tensor measurement used to start and stop the tractography
#stopping curvature (-stoppingcurvature): .7             Tractography will stop if radius of curvature becomes smaller than this number units are degrees per mm
#integration step length (-integrationsteplength): .5    Distance between points on the same fiber in mm
#use index space (-useindexspace): true                  Seed at the IJK voxel
#label (-label): 1                                       Label value that defined seeding region

####################################################################################

#make sure all data made it through
ls /projects/ncalarco/thesis/SPINS/Slicer/data/07_vtk | wc
