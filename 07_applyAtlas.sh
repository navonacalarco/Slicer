#!/bin/bash -l
#SBATCH --partition=high-moby
#SBATCH --nodes=1
#SBATCH --time=6:00:00
#SBATCH --export=ALL
#SBATCH --job-name Slicer
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.out
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/run_%a.err
#SBATCH --mem-per-cpu=36864
#SBATCH --cpus-per-task=1
#SBATCH --array=1-445

### mem-per-cpu went up from 18432 to 36864
### cpus-per-task went down from 2 to 1
### and array went from 1-445%20 to 1-445
### the command for updating this in the live job was:
#### scontrol update jobid=309759 minmemorycpu=36864 cpuspertask=1 mincpusnode=1 arraytaskthrottle=0
### Running a command like this will give an error, but
### this is only because it cannot update currently live
### jobs; all the still-PENDING array tasks will be updated.
### -- kevin 2020-03-02

#The files we ultimately want for supplementary steps are in /projects/ncalarco/thesis/SPINS/Slicer/data/registered/FiberMeasurements/
#Read documentation here: https://github.com/SlicerDMRI/whitematteranalysis/wiki/2c)-Running-the-Clustering-Pipeline-to-Cluster-a-Single-Subject-from-the-Atlas
#Also, see tutorial here: https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md
#Note that there are QC steps for each of these major 6 steps. See https://github.com/navonacalarco/Slicer/master/10_qualityControl.sh

#Submit with sbatch
cd $SLURM_SUBMIT_DIR

sublist="/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt"

index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \
   | tail -n 1
}

module load python/2.7.8-anaconda-2.1.0
module load python-extras/2.7.8
module load slicer/0,nightly #needs to be loaded first(?)
module load whitematteranalysis/2018-07-19

subject=`index`
inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/07_vtkTractsOnly/${subject}_eddy_fixed_SlicerTractography.vtk             # TRACTS.vtk file
outputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/08_registered
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtp
clusteredmrml=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/clustered_tracts_display_100_percent.mrml         # mrml file
tractsfile=/projects/ncalarco/thesis/SPINS/Slicer/documentation/tract_names.csv
filename=`echo $1 | sed "s/.*\///" | sed "s/\..*//"`
atlasDirectory=`dirname $atlas`
declare -a listHemispheres=("tracts_commissural" "tracts_left_hemisphere" "tracts_right_hemisphere")

mkdir -p $outputfolder

#STEP 1 OF 6: creates RegisterToAtlas
#this step registers each subject to the ORG800 atlas
if [ ! -e $outputfolder/RegisterToAtlas/${subject}/output_tractography/${subject}'_reg.vtk' ]; then
wm_register_to_atlas_new.py \
  $inputfolder $atlas $outputfolder/RegisterToAtlas
else
  echo "wm_register_to_atlas_new.py was already run on this subject!"
fi

#STEP 2 OF 6: creates ClusterFromAtlas
#then, create clusters - these are .vtp files of each of the n=800 clusters, for each participants
if [ ! -e $outputfolder/ClusterFromAtlas/${subject}'_reg' ]; then
wm_cluster_from_atlas.py \
  -l 20 \
  $outputfolder/RegisterToAtlas/${subject}_eddy_fixed_SlicerTractography/output_tractography/${subject}'_eddy_fixed_SlicerTractography_reg.vtk' \
  $atlasDirectory $outputfolder/ClusterFromAtlas
else
  echo "wm_cluster_from_atlas_new.py was already run on this subject!"
fi

#STEP 3 OF 6: creates OutliersPerSubject
#create a version without any outliers -- this is the same as above (.vtp for n=800), but without outliers
if [ ! -e $outputfolder/OutliersPerSubject/${subject}'_reg_outlier_removed' ]; then
wm_cluster_remove_outliers.py \
  -cluster_outlier_std 4 \
  $outputfolder/ClusterFromAtlas/${subject}'_eddy_fixed_SlicerTractography_reg' \
  $atlasDirectory \
  $outputfolder/OutliersPerSubject
else
  echo "wm_cluster_remove_outliers.py was already run on this subject!"
fi

#STEP 4 OF 6:creates ClusterByHemisphere
#creates .vtps of all the n=800 tracts by hemisphere (left, right, commissural, even if shouldn't exist, i.e., creates a 'left hemisphere' .vtp for commissural tracts)
if [ ! -e $outputfolder/ClusterByHemisphere/'OutliersPerSubject_'${subject} ]; then
wm_separate_clusters_by_hemisphere.py \
  -atlasMRML $clusteredmrml \
  $outputfolder/OutliersPerSubject/${subject}'_eddy_fixed_SlicerTractography_reg_outlier_removed'/ \
  $outputfolder/ClusterByHemisphere/'OutliersPerSubject_'${subject}
else
  echo "wm_separate_clusters_by_hemisphere.py was already run on this subject!"
fi

#STEP 5 OF 6: creates AppendClusters
#combines the n=800 fiber bundles into the n=41 named tracts -- again, by hemisphere
if [ ! -e $outputfolder/AppendClusters/'OutliersPerSubject_'${subject} ]; then
for hemisphere in "${listHemispheres[@]}"; do
echo $hemisphere
while read tractname; do
wm_append_clusters.py \
  -appendedTractName $tractname \
  -tractMRML $atlasDirectory/$tractname'.mrml' \
  $outputfolder/ClusterByHemisphere/'OutliersPerSubject_'${subject}/$hemisphere \
  $outputfolder/AppendClusters/'OutliersPerSubject_'${subject}/$hemisphere >> /projects/ncalarco/thesis/SPINS/Slicer/logs/log_wma.txt
done < $tractsfile
done
else
  echo "wm_separate_clusters_by_hemisphere.py was already run on this subject!"
fi

#STEP 6 OF 6:creates FiberMeasurements
#this step creates a csv file, again per hemisphere, with key metrics per n=41 named tracts, for each participant
if [ ! -e $outputfolder/FiberMeasurements/${subject} ]; then
for hemisphere in "${listHemispheres[@]}"; do
echo $hemisphere
mkdir -p $outputfolder/FiberMeasurements/${subject}/$hemisphere/
echo $outputfolder/FiberMeasurements/${subject}/$hemisphere >> /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/FiberMeasurements.txt;
FiberTractMeasurements \
  --outputfile $outputfolder/FiberMeasurements/${subject}/$hemisphere/${subject}'.csv' \
  --inputdirectory $outputfolder/AppendClusters/'OutliersPerSubject_'${subject}/$hemisphere \
  -i Fibers_File_Folder \
  --separator Tab \
  -f Column_Hierarchy
done
else
  echo "FiberTractMeasurements was already run on this subject!"
fi
