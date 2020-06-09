#!/bin/bash -l

####################################################################################
#Name:         #08_applyAtlas.sh

#Last updated: #2020-06-08

#Description:  #Runs all whitematteranalyses (registration to atlas, fiber bundling, etc)

#Submission:   #sbatch (remember to change the array to reflect number of participants)

#Notes:        #These scripts have positional arguments, so don't change order
               #These scripts call the whitematteranalysis package (cf. Slicer). This means that the commands can be run as is on a Mac (!); no need to change paths
               #All of these steps should be QC'd. Review outputs of https://github.com/navonacalarco/Slicer/blob/master/10_qualityControl.sh
               #Documentation here: https://github.com/SlicerDMRI/whitematteranalysis/wiki/2c)-Running-the-Clustering-Pipeline-to-Cluster-a-Single-Subject-from-the-Atlas
               #Tutorial here: https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md
               #To see the help file, type `/opt/quarantine/whitematteranalysis/2018-07-19/build/bin/SCRIPTNAME.py` -h (uses argparse)
####################################################################################

#load modules 
module load python/3.6.3-anaconda-5.0.1
module load slicer/0,nightly 
module load whitematteranalysis/2020-04-24

sublist="/projects/ncalarco/thesis/SPINS/Slicer/outputs/03_sublist.txt"

#define environment variables
inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/07_vtk/          
outputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/08_registered
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtp
atlasDirectory=`dirname $atlas`

#clusteredmrml=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/clustered_tracts_display_100_percent.mrml         
#tractsfile=/projects/ncalarco/thesis/SPINS/Slicer/documentation/tract_names.csv

#make output folder
mkdir -p $outputfolder

#--------------------------------------------------------------------------------------------------------------------
#STEP 1 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   01_TractRegistration
#Description:         Register each subject to the ORG800 atlas
#Notes:               We are using rigid-affine registration (cf. affine + nonrigid), which is appropriate for our population. 
#                     For HC populations, that have data similar in shape to the atlas, we would use a two-step registration of 'affine + nonrigid'
#                     The created .tfm file is the transform matrix
#Time:                Slow

for subject in $sublist; do
wm_register_to_atlas_new.py \
  -mode rigid_affine_fast \
  $inputfolder/${subject}_SlicerTractography.vtk \
  $atlas \
  $outputfolder/01_TractRegistration
done

#OPTIONAL ARGUMENTS
#-f     number of fibers      Number of fibers to analyze. Default is 20,000
#-l     min fiber length      Minimum length (mm) of fibers to analyze. Default is 40mm
#-lmax  max fiber length      Maximum length (mm) of fibers to analyze. Default is 260mm

#--------------------------------------------------------------------------------------------------------------------
#STEP 2 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   02_FiberClustering/InitialClusters/ 
#Description:         Create n=800 clusters from fibers in accordance with ORG atlas
#Note:                Previously had flag for `-l 20`
#Time:                Fast

for subject in $sublist; do
wm_cluster_from_atlas.py \
  $outputfolder/01_TractRegistration/${subject}_SlicerTractography/output_tractography/${subject}'_SlicerTractography_reg.vtk' \
  $atlasDirectory \
  $outputfolder/02_FiberClustering/InitialClusters/
done

#OPTIONAL ARGUMENTS
#-f   Number of fibers; default is all fibers
#-l   Minimum fiber length (mm) of fibers to analyze. Default is 60mm

#--------------------------------------------------------------------------------------------------------------------
#STEP 3 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   02_FiberClustering/OutlierRemovedClusters
#Description:         Removes outliers (at SD=4) from the n=800 clusters created in Step 2
#Time:                Slow
#Notes:               See a lot of "cluster is empty in subject". There are very few such messages in example data.

for subject in $sublist; do
wm_cluster_remove_outliers.py \
  -cluster_outlier_std 4 \
  $outputfolder/02_FiberClustering/InitialClusters/${subject}'_SlicerTractography_reg' \
  $atlasDirectory \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters
done

#--------------------------------------------------------------------------------------------------------------------
#STEP 4 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   NA
#Description:         This script assess the hemispheric location (left, right or commissural) of each fiber in each fiber cluster.
#                     Each cluster (the vtp file) is updated by adding additional information about hemisphere location.
#                     This information is used to separate the clusters after transforming them back to the input tractography space
#Time:                Fast

for subject in $sublist; do
wm_assess_cluster_location_by_hemisphere.py \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}'_SlicerTractography_reg_outlier_removed' \
  -clusterLocationFile $atlasDirectory/cluster_hemisphere_location.txt
done

#OPTIONAL ARGUMENTS
#-pthresh   The percent of a fiber that has to be in one hemisphere to consider the fiber as part of that hemisphere.
#           The default number is 0.6. A higher number tends to label fewer fibers as hemispheric and more as commissural. 
#           This parameter can be skipped when using a pre-provided atlas because a cluster location file that defines the
#           commissural and hemispheric clusters is provided. 
#           We use ''-clusterLocationFile'' to specify the path of the location file.

#--------------------------------------------------------------------------------------------------------------------
#STEP 5 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   02_FiberClustering/TransformedClusters
#Description:         This script applies the inverse transform matrix established in STEP 4, i.e., it transforms them to the input tractography (DWI) space
#Time:                Fast
#Note:                If we had used two-step registration in Step 1 (we did not), we would have to do a two-step transformation here, as well
#                     whitematteranalysis calls Slicer, and briefly opens the Slicer GUI; on MAC, change Slicer path to /Applications/Slicer.app/Contents/MacOS/Slicer

#transform fiber locations
for subject in $sublist; do
wm_harden_transform.py \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}_SlicerTractography_reg_outlier_removed/ \
  $outputfolder/02_FiberClustering/TransformedClusters/${subject}_SlicerTractography/ \
  /opt/quarantine/slicer/nightly/build/Slicer \
  -i \
  -t $outputfolder/01_TractRegistration/${subject}_SlicerTractography/output_tractography/itk_txform_${subject}_SlicerTractography.tfm
done

#--------------------------------------------------------------------------------------------------------------------
#STEP 6 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   02_FiberClustering/SeparatedClusters, and three subdirectories, in subject DWI space 
#Description:         This script creates .vtps of all the n=800 tracts by hemisphere (left, right, commissural) 
#Time:                Fast    

for subject in $sublist; do
wm_separate_clusters_by_hemisphere.py \
  $outputfolder/02_FiberClustering/TransformedClusters/${subject}_SlicerTractography \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}
done
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 7 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   03_Anatomical tracts
#Description:         Computers anatomical fiber tracts according to atlas (73 anatomical tracts defined by ORG)
#Time:                Fast    
#Note:                 

for subject in $sublist; do
wm_append_clusters_to_anatomical_tracts.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject} \
  $atlasDirectory/ \
  $outputfolder/03_AnatomicalTracts/${subject}
done

#--------------------------------------------------------------------------------------------------------------------
#STEP 8 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   04_DiffusionMeasurements
#Description:         Fiber measurements by cluster. Creates a single .csv with values for each participants for the n=800, by L, R, C 
#Time:                Fast    

#left
for subject in $sublist; do
wm_diffusion_measurements.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}/tracts_left_hemisphere/ \
  $outputfolder/04_DiffusionMeasurements/${subject}_left_hemisphere_clusters.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
  #/Applications/Slicer.app/Contents/Extensions-28257/SlicerDMRI/lib/Slicer-4.10/cli-modules/FiberTractMeasurements
done

#right
for subject in $sublist; do
wm_diffusion_measurements.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}/tracts_right_hemisphere/ \
  $outputfolder/04_DiffusionMeasurements/${subject}_right_hemisphere_clusters.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
done
  
#commissural
for subject in $sublist; do
wm_diffusion_measurements.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}/tracts_commissural/ \
  $outputfolder/04_DiffusionMeasurements/${subject}_commissural_clusters.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
done
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 9 OF 9
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   04_DiffusionMeasurements
#Description:         Fiber measurements by tract. Create a single .csv with values for each participants for the n=73 tracts (N=41 unique), by L, R, C
#Time:                Fast    

#anatomical tracts
for subject in $sublist; do
wm_diffusion_measurements.py \
  $outputfolder/03_AnatomicalTracts/${subject} \
  $outputfolder/04_DiffusionMeasurements/${subject}_anatomical_tracts.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
done

