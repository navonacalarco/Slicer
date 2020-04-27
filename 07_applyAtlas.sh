#!/bin/bash -l

####################################################################################
#Name:         #07_applyAtlas.sh

#Last updated: #2020-04-26

#Description:  #Runs all whitematteranalyses (registration to atlas, fiber bundling, etc)

#Submission:   #sbatch (remember to change the array to reflect number of participants)

#Notes:        #These scripts have positional arguments, so don't change order
               #All of these steps should be QC'd. Review outputs of https://github.com/navonacalarco/Slicer/blob/master/10_qualityControl.sh
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
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtp
#clusteredmrml=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/clustered_tracts_display_100_percent.mrml         
#tractsfile=/projects/ncalarco/thesis/SPINS/Slicer/documentation/tract_names.csv
atlasDirectory=`dirname $atlas`

#make output folder
mkdir -p $outputfolder

#--------------------------------------------------------------------------------------------------------------------
#STEP 1 OF 7
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   01_TractRegistration
#Description:         Register each subject to the ORG800 atlas
#Notes:               We are using rigid-affine registration (cf. affine + nonrigid), which is appropriate for our population. 
#                     The created .tfm file is the transform matrix
#Time:                Slow

if [ ! -e $outputfolder/01_TractRegistration/${subject}/output_tractography/${subject}'_reg.vtk' ]; then
wm_register_to_atlas_new.py \
  -mode rigid_affine_fast \
  $inputfolder \                          #inputSubject
  $atlas \                                #inputAtlas
  $outputfolder/01_TractRegistration      #outputDirectory
else
  echo "wm_register_to_atlas_new.py was already run on this subject!"
fi

#OPTIONAL ARGUMENTS
#-f     number of fibers      Number of fibers to analyze. Default is 20,000
#-l     min fiber length      Minimum length (mm) of fibers to analyze. Default is 40mm
#-lmax  max fiber length      Maximum length (mm) of fibers to analyze. Default is 260mm

#--------------------------------------------------------------------------------------------------------------------
#STEP 2 OF 7
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   FiberClustering/InitialClusters/ 
#Description:         Create n=800 clusters from fibers in accordance with ORG atlas
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

#OPTIONAL ARGUMENTS
#-f   Number of fibers; default is all fibers
#-l   Minimum fiber length (mm) of fibers to analyze. Default is 60mm

#--------------------------------------------------------------------------------------------------------------------
#STEP 3 OF 7
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   FiberClustering/OutlierRemovedClusters
#Description:         Removes outliers (at SD=4) from the n=800 clusters created in Step 2
#Time:                Slow
#Notes:               See a lot of "cluster is empty in subject". There are very few such messages in example data.

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
#STEP 4 OF 7 
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

#OPTIONAL ARGUMENTS
#-pthresh   The percent of a fiber that has to be in one hemisphere to consider the fiber as part of that hemisphere.
#           The default number is 0.6. A higher number tends to label fewer fibers as hemispheric and more as commissural.

#--------------------------------------------------------------------------------------------------------------------
#STEP 5 OF 7
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   02/FiberClustering/TransformedClusters
#Description:         This script applies the inverse transform matrix established in STEP 4, i.e., it transforms them to the input tractography space
#Time:                Fast
#Note:                whitematteranalysis calls Slicer, and briefly opens the Slicer GUI; this fails over remote (external display)

#transform fiber locations
wm_harden_transform.py \
  $outputfolder/02_FiberClustering/OutlierRemovedClusters/${subject}_eddy_fixed_SlicerTractography_reg_outlier_removed/ \
  $outputfolder/02_FiberClustering/TransformedClusters/${subject}_eddy_fixed_SlicerTractography/ \
  /opt/quarantine/slicer/nightly/build/Slicer \
  -i \
  -t $outputfolder/01_TractRegistration/${subject}_eddy_fixed_SlicerTractography/output_tractography/itk_txform_${subject}_eddy_fixed_SlicerTractography.tfm

#--------------------------------------------------------------------------------------------------------------------
#STEP 6 OF 7 
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   FiberClustering/SeparatedClusters, and three subdirectories 
#Description:         This script creates .vtps of all the n=800 tracts by hemisphere (left, right, commissural) 
#Time:                Fast    

wm_separate_clusters_by_hemisphere.py \
  $outputfolder/02_FiberClustering/TransformedClusters/${subject}_eddy_fixed_SlicerTractography \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}

#--------------------------------------------------------------------------------------------------------------------
#STEP 7 OF 7
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   04_DiffusionMeasurements
#Description:         Create a single .csv with values for each participants for the n=73 tracts (N=41 unique), by L, R, C
#Time:                Fast    
#Note:                Here, I have opted to take measurements by tract, and not hemisphere. 

#left
wm_diffusion_measurements.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}/tracts_left_hemisphere/ \
  $outputfolder/04_DiffusionMeasurements/${subject}_left_hemisphere_clusters.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
  #/Applications/Slicer.app/Contents/Extensions-28257/SlicerDMRI/lib/Slicer-4.10/cli-modules/FiberTractMeasurements
  
#right
wm_diffusion_measurements.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}/tracts_right_hemisphere/ \
  $outputfolder/04_DiffusionMeasurements/${subject}_right_hemisphere_clusters.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
  
#commissural
wm_diffusion_measurements.py \
  $outputfolder/02_FiberClustering/SeparatedClusters/${subject}/tracts_commissural/ \
  $outputfolder/04_DiffusionMeasurements/${subject}_commissural_clusters.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 8 OF 7
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   04_DiffusionMeasurements
#Description:         Create a single .csv with values for each participants for the n=73 tracts (N=41 unique), by L, R, C
#Time:                Fast    
#Note:                Here, I have opted to take measurements by tract, and not hemisphere. 

#anatomical tracts
wm_diffusion_measurements.py \
  $outputfolder/03_AnatomicalTracts/${subject} \
  $outputfolder/04_DiffusionMeasurements/${subject}_anatomical_tracts.csv \
  /opt/quarantine/slicer/nightly/build/lib/Slicer-4.9/cli-modules/FiberTractMeasurements


