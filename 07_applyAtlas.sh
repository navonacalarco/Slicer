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

### note from Kevin: we can ammend a live slurm job (i.e., all still-PENDING array tasks) as follows:
#### scontrol update jobid=309759 minmemorycpu=36864 cpuspertask=1 mincpusnode=1 arraytaskthrottle=0
### (it will give an error but can disregard; error related to not updating currently running jobs)

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

##############
#STEP 1 OF 8
##############

#creates 01_TractRegistration (formerly RegisterToAtlas)
#this step registers each subject to the ORG800 atlas
#note: we are using rigid-affine registration (cf. affine + nonrigid)
#note: the .tfm file is the transform matrix
if [ ! -e $outputfolder/01_TractRegistration/${subject}/output_tractography/${subject}'_reg.vtk' ]; then
wm_register_to_atlas_new.py -mode rigid_affine_fast \
  $inputfolder \
  $atlas \
  $outputfolder/01_TractRegistration
else
  echo "wm_register_to_atlas_new.py was already run on this subject!"
fi

##############
#STEP 2 OF 8
##############

#creates FiberClustering/InitialClusters/ (formerly ClusterFromAtlas)
#then, create clusters - these are .vtp files of each of the n=800 clusters, for each participants
#note: previously had flag for `-l 20`
if [ ! -e $outputfolder/02_FiberClustering/InitialClusters/${subject}'_reg' ]; then
wm_cluster_from_atlas.py \
  $outputfolder/01_TractRegistration/${subject}_eddy_fixed_SlicerTractography/output_tractography/${subject}'_eddy_fixed_SlicerTractography_reg.vtk' \
  $atlasDirectory \
  $outputfolder/02_FiberClustering/InitialClusters/
else
  echo "wm_cluster_from_atlas_new.py was already run on this subject!"
fi

##############
#STEP 3 OF 8
##############

#creates FiberClustering/OutlierRemovedClusters/ (formerly OutliersPerSubject)
#create a version without any outliers -- this is the same as above (.vtp for n=800), but without outliers
#note: we are removing outliers at the 4SD threshold
if [ ! -e $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}'_reg_outlier_removed' ]; then
wm_cluster_remove_outliers.py \
  -cluster_outlier_std 4 \
  $outputfolder/02_FiberClustering/InitialClusters/${subject}'_eddy_fixed_SlicerTractography_reg' \
  $atlasDirectory \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters
else
  echo "wm_cluster_remove_outliers.py was already run on this subject!"
fi

##############
#STEP 4 OF 8
##############

#check cluster location 
#this script assess the hemispheric location (left, right or commissural) of each fiber in each fiber cluster
#each cluster (the vtp file) is updated by adding additional information about hemisphere location
#this information is used to separate the clusters after transforming them back to the input tractography space
wm_assess_cluster_location_by_hemisphere.py \
   $outputfolder/FiberClustering/OutlierRemovedClusters/${subject}'_reg_outlier_removed' \ 
   -clusterLocationFile \
   $atlasDirectory/cluster_hemisphere_location.txt

##############
#STEP 5 OF 8
##############

#transform fiber locations
wm_harden_transform.py -i -t \
   $outputfolder/01_TractRegistration/${subject}_eddy_fixed_SlicerTractography/output_tractography/itk_txform_{subject}_eddy_fixed_SlicerTractography.tfm \
   ./FiberClustering/OutlierRemovedClusters/${subject}'_reg_outlier_removed' \
   ./FiberClustering/TransformedClusters/${subject} \
   /opt/quarantine/slicer/0,nightly  #or maybe no 0?

##############
#STEP 6 OF 8
##############

#creates /FiberClustering/SeparatedClusters (formerly ClusterByHemisphere)
#creates .vtps of all the n=800 tracts by hemisphere (left, right, commissural, even if shouldn't exist, i.e., creates a 'left hemisphere' .vtp for commissural tracts)
if [ ! -e $outputfolder/FiberClustering/SeparatedClusters/'OutliersPerSubject_'${subject} ]; then
wm_separate_clusters_by_hemisphere.py \
  #-atlasMRML $clusteredmrml \
  $outputfolder/FiberClustering/TransformedClusters/${subject} \
  $outputfolder/FiberClustering/SeparatedClusters/${subject}
else
  echo "wm_separate_clusters_by_hemisphere.py was already run on this subject!"
fi

##############
#STEP 7 OF 8
##############

#creates Anatomical tracts (formerly AppendClusters)
#combines the n=800 fiber bundles into the n=41 named tracts -- again, by hemisphere
#if [ ! -e $outputfolder/AppendClusters/'OutliersPerSubject_'${subject} ]; then
#for hemisphere in "${listHemispheres[@]}"; do
#echo $hemisphere
#while read tractname; do
#wm_append_clusters.py \
#  -appendedTractName $tractname \
#  -tractMRML $atlasDirectory/$tractname'.mrml' \
#  $outputfolder/ClusterByHemisphere/'OutliersPerSubject_'${subject}/$hemisphere \
#  $outputfolder/AppendClusters/'OutliersPerSubject_'${subject}/$hemisphere >> /projects/ncalarco/thesis/SPINS/Slicer/logs/log_wma.txt
#done < $tractsfile
#done
#else
#  echo "wm_append_clusters.py was already run on this subject!"
#fi

wm_append_clusters_to_anatomical_tracts.py \
   $outputfolder/FiberClustering/SeparatedClusters \
   $atlas \
   $outputfolder/AnatomicalTracts

##############
#STEP 8 OF 8
##############

#creates FiberMeasurements
#this step creates a csv file, again per hemisphere, with key metrics per n=41 named tracts, for each participant
if [ ! -e $outputfolder/FiberMeasurements/${subject} ]; then
for hemisphere in "${listHemispheres[@]}"; do
echo $hemisphere
mkdir -p $outputfolder/FiberClustering/SeparatedClusters/${subject}/$hemisphere/
echo $outputfolder/FiberClustering/SeparatedClusters/${subject}/$hemisphere >> /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/FiberMeasurements.txt;
FiberTractMeasurements \
  --outputfile $outputfolder/FiberClustering/SeparatedClusters/${subject}/$hemisphere/${subject}'.csv' \
  --inputdirectory $outputfolder/AnatomicalTracts/'OutliersPerSubject_'${subject}/$hemisphere \
  -i Fibers_File_Folder \
  --separator Tab \
  -f Column_Hierarchy
done
else
  echo "FiberTractMeasurements was already run on this subject!"
fi
