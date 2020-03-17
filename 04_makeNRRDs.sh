#We need to convert to .nrrds
#Note: need to manually make the 04_nrrd directory!

module load slicer/0,nightly
module load SGE-extras/1.0

input_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT"
output_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/04_nrrd"
data_dir="/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"

while read id; do
echo ${id}
if [ ! -e ${output_dir}/${id}/${id}_eddy_fixed.nrrd ]; then

DWIConvert --inputVolume ${input_dir}/${id}/${id}_eddy_fixed.nii.gz --conversionMode FSLToNrrd --inputBValues ${data_dir}/${id}/*/dwi/${id}_*desc-eddy_dwi.bval --inputBVectors ${data_dir}/${id}/*/dwi/${id}_*desc-eddy_dwi.bvec --outputVolume ${output_dir}/${id}_eddy_fixed.nrrd
else
  echo ${id} "is converted to nrrd"
fi
done < /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt
