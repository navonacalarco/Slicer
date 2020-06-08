#!/bin/bash

####################################################################################
#Name:         #05_makeNRRDs.sh

#Last updated: #2020-06-07

#Description:  #Convert .nii to .nrrd, as required by Slicer to perform tractography

#Submission:   #bash

#Notes:        #The Slicer tutorial states to use the --useBMatrixGradientDirections flag for Siemens, which: 
#              Fill the nhdr header with the gradient directions and bvalues computed
#              out of the BMatrix. Only changes behavior for Siemens data.  In some
#              cases the standard public gradients are not properly computed.  The
#              gradients can emperically computed from the private BMatrix fields.
#              In some cases the private BMatrix is consistent with the public
#              grandients, but not in all cases, when it exists BMatrix is usually
#              most robust. (value: 0)
#              reference: http://dmri.slicer.org/tutorials/Slicer-4.8/DWIConverterTutorial.pdf
####################################################################################

#load modules
module load slicer/0,nightly
module load SGE-extras/1.0

#make a separate participant list for Simens and non-Siemens
awk '( $1 ~ /CMP|MRP|ZHP/ ) { print $1 > "05_sublistPrisma.txt" }; \
     ( $1 ~ /CMH|MRC|ZHH/ ) { print $1 > "05_sublistNonprisma.txt" }' \
    /projects/ncalarco/thesis/SPINS/Slicer/outputs/03_sublist.txt

#define directory variables
data_dir="/projects/ncalarco/thesis/SPINS/Slicer/data"
input_dir_dwi="${data_dir}/04_dmriprep_INT"
input_dir_b="${data_dir}/01_dmriprep" 
output_dir="${data_dir}/05_nrrd"

#make output directory
mkdir -p $output_dir

#############################################################################
#for Siemens Prisma subjects (CMP, MRP, ZHP)
#############################################################################

#run conversion with dwiconvert (native to Slicer)
while read subject; do
echo ${subject}
if [ ! -e ${output_dir}/${subject}.nrrd ]; then

DWIConvert --inputVolume ${input_dir_dwi}/${subject}_*brainsuite_fixed.nii.gz \
   --conversionMode FSLToNrrd \
   --inputBValues ${input_dir_b}/${subject}/*/dwi/${subject}_*desc-brainsuite_dwi.bval \
   --inputBVectors ${input_dir_b}/${subject}/*/dwi/${subject}_*desc-brainsuite_dwi.bvec \
   --outputVolume ${output_dir}/${subject}.nrrd \
   --useBMatrixGradientDirections
else
  echo ${subject} "is converted to nrrd"
fi
done < /projects/ncalarco/thesis/SPINS/Slicer/outputs/05_sublistPrisma.txt


#############################################################################
#for non-Prisma subjects (CMH, MRC, ZHH)
#############################################################################

#run conversion with dwiconvert (native to Slicer)
while read subject; do
echo ${subject}
if [ ! -e ${output_dir}/${subject}.nrrd ]; then

DWIConvert --inputVolume ${input_dir_dwi}/${subject}_*brainsuite_fixed.nii.gz \
   --conversionMode FSLToNrrd \
   --inputBValues ${input_dir_b}/${subject}/*/dwi/${subject}_*desc-brainsuite_dwi.bval \
   --inputBVectors ${input_dir_b}/${subject}/*/dwi/${subject}_*desc-brainsuite_dwi.bvec \
   --outputVolume ${output_dir}/${subject}.nrrd
else
  echo ${subject} "is converted to nrrd"
fi
done < /projects/ncalarco/thesis/SPINS/Slicer/outputs/05_sublistNonPrisma.txt
