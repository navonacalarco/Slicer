#!/bin/bash -l

#SBATCH --partition=high-moby
#SBATCH --array=1-454
#SBATCH --nodes=1
#SBATCH --time=20:00
#SBATCH --export=ALL
#SBATCH --job-name=Slicer
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.out
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.err
#SBATCH --mem-per-cpu=1G

#to check overview of cluster, type sinfo
#make sure you change the array to show the correct number of participants
#submit with sbatch
#check with sacct to see if running
#check individual jobs with scontrol jobid=WHATEVERthenumberis, from sacct, | grep AllocNode
#then, ssh to the computer that sacct tells us
#to cancel, scancel -u ncalarco
#also sview
#https://github.com/TIGRLab/TIGRSlurm-Docs

cd $SLURM_SUBMIT_DIR

sublist="/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt"

index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \
   | tail -n 1
}

module load python/2.7.9-anaconda-2.1.0-150119
module load slicer/4.8.1
module load DTIPrep/1.2.8

inputdir='/projects/ncalarco/thesis/SPINS/Slicer/data/04_nrrd'
dtiprep_protocol='/projects/ncalarco/thesis/SPINS/Slicer/data/05_dtiprep_protocols'
outputdir='/projects/ncalarco/thesis/SPINS/Slicer/data/06_vtk'

export inputimage="${inputdir}/`index`*.nrrd"
export stem="$(basename $inputimage .nrrd)"
export output_name="${outputdir}/${stem}"

#dwi estimation
Slicer --launch DWIToDTIEstimation \
  --enumeration WLS \
  --shiftNeg \
  ${inputimage} \
  ${output_name}_DTI.nrrd \
  ${output_name}_SCALAR.nrrd

#volume masking
Slicer --launch DiffusionWeightedVolumeMasking \
  --removeislands \
  ${inputimage} \
  ${output_name}_SCALAR.nrrd \
  ${output_name}_MASK.nrrd

####################################################################################
#NOTE: For tractography, I am  have decided to use masks made in Slicer
#This should be sufficient
#If issues, can use masks made with brainsuite, or another software
####################################################################################

#label map seeding
Slicer --launch TractographyLabelMapSeeding \
${output_name}_DTI.nrrd \
${output_name}_SlicerTractography.vtk \
  --inputroi ${output_name}_MASK.nrrd \  
  --useindexspace \
  --stoppingvalue 0.10

#one this script has run, for ease, move over just the tractography files to a separate atlasDirectory
#mkdir /projects/ncalarco/thesis/SPINS/Slicer/data/07_vtkTractsOnly
#find . -name '*_SlicerTractography.vtk' -exec cp -t ../07_vtkTractsOnly/ {} +
#ls /projects/ncalarco/thesis/SPINS/Slicer/data/07_vtkTractsOnly | wc #449
