#!/bin/bash -l

####################################################################################
#Name:         #07_applyAtlas.sh

#Last updated: #2020-04-22

#Description:  #Runs all whitematteranalyses (registration to atlas, fiber bundling, etc)

#Submission:   #sbatch (remember to change the array to reflect number of participants)

#Notes:        #All of these steps should be QC'd. Review outputs of https://github.com/navonacalarco/Slicer/blob/master/10_qualityControl.sh
               #Documentation here: https://github.com/SlicerDMRI/whitematteranalysis/wiki/2c)-Running-the-Clustering-Pipeline-to-Cluster-a-Single-Subject-from-the-Atlas
               #Tutorial here: https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md
               #To see the help file, type python `/opt/quarantine/whitematteranalysis/2018-07-19/build/bin/SCRIPTNAME.py` -h (uses argparse)
####################################################################################

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

#load modules 
module load python/3.6.3-anaconda-5.0.1
module load python-extras/2.7.8
module load slicer/0,nightly 
module load whitematteranalysis/2020-04-24

#get lists of subjects
cd $SLURM_SUBMIT_DIR

sublist="/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt"

index() {
   head -n $SLURM_ARRAY_TASK_ID $sublist \  #change to `head -n 1 $sublist` if want to test on one participant
   | tail -n 1
}

subject=`index`

#define environment variables
inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/07_vtkTractsOnly/${subject}_eddy_fixed_SlicerTractography.vtk             
outputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/08_registered
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtpin
clusteredmrml=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/clustered_tracts_display_100_percent.mrml         
tractsfile=/projects/ncalarco/thesis/SPINS/Slicer/documentation/tract_names.csv
filename=`echo $1 | sed "s/.*\///" | sed "s/\..*//"`
atlasDirectory=`dirname $atlas`
declare -a listHemispheres=("tracts_commissural" "tracts_left_hemisphere" "tracts_right_hemisphere")

#make output folder
mkdir -p $outputfolder

#--------------------------------------------------------------------------------------------------------------------
#STEP 1 OF 8
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   01_TractRegistration (formerly RegisterToAtlas)
#Description:         Register each subject to the ORG800 atlas
#Notes:               We are using rigid-affine registration (cf. affine + nonrigid), which is appropriate for our population. The created .tfm file is the transform matrix
#Time:                Slow

if [ ! -e $outputfolder/01_TractRegistration/${subject}/output_tractography/${subject}'_reg.vtk' ]; then
wm_register_to_atlas_new.py \
  -mode rigid_affine_fast \
  $inputfolder \
  $atlas \
  $outputfolder/01_TractRegistration
else
  echo "wm_register_to_atlas_new.py was already run on this subject!"
fi

#--------------------------------------------------------------------------------------------------------------------
#STEP 2 OF 8
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   FiberClustering/InitialClusters/ (formerly ClusterFromAtlas)
#Description:         Create n=800 clusters from fibers 
#Note:                Previously had flag for `-l 20`
#Time:                Fast

if [ ! -e $outputfolder/02_FiberClustering/InitialClusters/${subject}'_reg' ]; then
wm_cluster_from_atlas.py \
  $outputfolder/01_TractRegistration/${subject}_eddy_fixed_SlicerTractography/output_tractography/${subject}'_eddy_fixed_SlicerTractography_reg.vtk' \
  $atlasDirectory \
  $outputfolder/02_FiberClustering/InitialClusters/
else
  echo "wm_cluster_from_atlas_new.py was already run on this subject!"
fi

#--------------------------------------------------------------------------------------------------------------------
#STEP 3 OF 8
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   FiberClustering/OutlierRemovedClusters/ (formerly OutliersPerSubject)
#Description:         Removes outliers (at SD=4) from the n=800 clusters created in Step 2
#Time:                Slow

if [ ! -e $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}'_reg_outlier_removed' ]; then
wm_cluster_remove_outliers.py \
  -cluster_outlier_std 4 \
  $outputfolder/02_FiberClustering/InitialClusters/${subject}'_eddy_fixed_SlicerTractography_reg' \
  $atlasDirectory \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters
else
  echo "wm_cluster_remove_outliers.py was already run on this subject!"
fi

#--------------------------------------------------------------------------------------------------------------------
#STEP 4 OF 8 
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   NA
#Description:         This script assess the hemispheric location (left, right or commissural) of each fiber in each fiber cluster.
#                     Each cluster (the vtp file) is updated by adding additional information about hemisphere location.
#                     This information is used to separate the clusters after transforming them back to the input tractography space
#Time:                Fast

if [ ! -e $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}'_eddy_fixed_SlicerTractography_reg_outlier_removed'/cluster_location_by_hemisphere.log ]; then
wm_assess_cluster_location_by_hemisphere.py \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}'_eddy_fixed_SlicerTractography_reg_outlier_removed' \
  -clusterLocationFile $atlasDirectory/cluster_hemisphere_location.txt
else
  echo "wm_assess_cluster_location_by_hemisphere.py was already run on this subject!"
fi

#--------------------------------------------------------------------------------------------------------------------
#STEP 5 OF 8 ~~~HAVEN'T ATTEMPTED~~~
#--------------------------------------------------------------------------------------------------------------------

#transform fiber locations
wm_harden_transform.py -i -t \
   $outputfolder/01_TractRegistration/${subject}_eddy_fixed_SlicerTractography/output_tractography/itk_txform_{subject}_eddy_fixed_SlicerTractography.tfm \
   ./FiberClustering/OutlierRemovedClusters/${subject}'_reg_outlier_removed' \
   ./FiberClustering/TransformedClusters/${subject} \
   /opt/quarantine/slicer/0,nightly  #or maybe no 0?

#--------------------------------------------------------------------------------------------------------------------
#STEP 6 OF 8 ~~~MISSING SCRIPT~~~
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   FiberClustering/SeparatedClusters (formerly ClusterByHemisphere)
#Description:         This script creates .vtps of all the n=800 tracts by hemisphere (left, right, commissural) even if shouldn't exist 
#                     A .vtp is created even if a given tract should't exist, i.e., creates a 'left hemisphere' .vtp for commissural tracts
#                     The default hemisphere fiber percent threshold is 0.6                    
#Note:                NEED TO CHANGE INPUT TO TransformedClusters WHEN STEP 5 WORKS
#Time:                

if [ ! -e $outputfolder/02_FiberClustering/SeparatedClusters/'OutliersPerSubject_'${subject} ]; then
wm_separate_clusters_by_hemisphere.py \
  -atlasMRML $clusteredmrml \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters \ 
  $outputfolder/02_FiberClustering/SeparatedClusters
else
  echo "wm_separate_clusters_by_hemisphere.py was already run on this subject!"
fi

#--------------------------------------------------------------------------------------------------------------------
#STEP 7 OF 8
#--------------------------------------------------------------------------------------------------------------------

#creates Anatomical tracts (formerly AppendClusters)
#combines the n=800 fiber bundles into the n=41 named tracts -- again, by hemisphere
#if [ ! -e $outputfolder/AppendClusters/'OutliersPerSubject_'${subject} ]; then
#for hemisphere in "${listHemispheres[@]}"; do
#echo $hemisphere
#while read tractname; do
#wm_append_clusters_to_anatomical_tracts.py \   #was previousy wm_append_clusters.py
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

#--------------------------------------------------------------------------------------------------------------------
#STEP 8 OF 8
#--------------------------------------------------------------------------------------------------------------------

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
