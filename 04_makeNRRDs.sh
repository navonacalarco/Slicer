#We need to convert to .nrrds, as Slicer requires .nrrds to perform tractography

module load slicer/0,nightly
module load SGE-extras/1.0

input_dir_dwi="/projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT"
input_dir_masks="/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"  #make sure no integer problem with masks
output_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/04_nrrd"
data_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"

#make output 04_nrrd directory
mkdir -p $output_dir

############################
#first, convert DWI data
############################

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

############################
#second, convert masks
############################

#Confirm I need bvec and bval to convert the mask to .nrrd?

while read id; do
echo ${id}
if [ ! -e ${output_dir}/${id}/${id}_mask.nrrd ]; then

DWIConvert --inputVolume ${input_dir_masks}/${id}/*/dwi/*brainsuite_mask.nii.gz 
   --conversionMode FSLToNrrd \
   --inputBValues ${data_dir}/${id}/*/dwi/${id}_*desc-eddy_dwi.bval \
   --inputBVectors ${data_dir}/${id}/*/dwi/${id}_*desc-eddy_dwi.bvec \
   --outputVolume ${output_dir}/${id}_mask.nrrd 
else
  echo ${id} "is converted to nrrd"
fi
done < /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt
