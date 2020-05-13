#!/bin/bash

####################################################################################
#Name:         #04_makeNRRDs.sh

#Last updated: #2020-03-17

#Description:  #Convert .nii to .nrrd, as required by Slicer to perform tractography

#Submission:   #bash

#Notes:        #May need to follow up: do I need to convert Siemens data to .nrrd 
               #differently than non-Siemens? Fan suggests may want to use 
               #the --useBMatrixGradientDirections flag, but all looks ok...
               #reference: http://dmri.slicer.org/tutorials/Slicer-4.8/DWIConverterTutorial.pdf
####################################################################################

#load modules
module load slicer/0,nightly
module load SGE-extras/1.0

#define directory variables
input_dir_dwi="/projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT"
input_dir_masks="/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"  #m
output_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/04_nrrd"
data_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"

#make output directory
mkdir -p $output_dir

#run conversion with dwiconvert (native to Slicer)
while read id; do
echo ${id}
if [ ! -e ${output_dir}/${id}_eddy_fixed.nrrd ]; then

DWIConvert --inputVolume ${input_dir_dwi}/${id}_eddy_fixed.nii.gz \
   --conversionMode FSLToNrrd \
   --inputBValues ${data_dir}/${id}/*/dwi/${id}_*desc-eddy_dwi.bval \
   --inputBVectors ${data_dir}/${id}/*/dwi/${id}_*desc-eddy_dwi.bvec \
   --outputVolume ${output_dir}/${id}_eddy_fixed.nrrd
else
  echo ${id} "is converted to nrrd"
fi
done < /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt
