#!/bin/bash -l

####################################################################################
#Name:         #10_qualityControl.sh

#Last updated: #2020-04-27

#Description:  #Runs quality control on all steps in 07_applyAtlas.sh

#Submission:   #sbatch (remember to change the array to reflect number of participants)

#Notes:        #These scripts have positional arguments, so don't change order
               #These scripts call the whitematteranalysis package (cf. Slicer). This means that the commands can be run as is on a Mac (!); no need to change path
               #Documentation here: https://github.com/SlicerDMRI/whitematteranalysis/wiki/2c)-Running-the-Clustering-Pipeline-to-Cluster-a-Single-Subject-from-the-Atlas
               #Tutorial here: https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md
               #To see the help file, type python `/opt/quarantine/whitematteranalysis/2018-07-19/build/bin/SCRIPTNAME.py` -h (uses argparse)
####################################################################################

#SBATCH --array=18268
#SBATCH --cpus-per-task=1
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/SlicerQC/SlicerQC_%A_%a.err
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/SlicerQC/SlicerQC_%A_%a.out
#SBATCH --job-name=SlicerQC2_%j

#purge modules in my environment -- affecting queue...
module purge

#load required modules
module load python/3.6.3-anaconda-5.0.1
module load slicer/0,nightly 
module load whitematteranalysis/2020-04-24

#define environment variables
inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/
outputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/09_QC
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtp

#make output folder
mkdir -p $outputfolder

#--------------------------------------------------------------------------------------------------------------------
#STEP 1 OF X
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   10_QC/01_tractography
#Description:         QC tractography across all participants (catch early errors in tractography)
#Notes:               Expected output: html; whole brain, 6 views, all grey
#Time:

wm_quality_control_tractography.py \
  ${inputfolder}/07_vtkTractsOnly \
  ${outputfolder}/QC_01_tractography
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 2 OF X
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/02_overlapPreRegistration
#Description:        Show overlap of input tractography (red) and the atlas (yellow) before registration

wm_quality_control_tract_overlap.py \ 
  ${atlas} \
  ${inputfolder}/07_vtkTractsOnly/${subject}_eddy_fixed_SlicerTractography.vtk \
  ${outputfolder}/QC_02_overlapBeforeRegistration/${subject}/

#--------------------------------------------------------------------------------------------------------------------
#STEP 3 OF X
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/03_overlapPostRegistration
#Description:        Show overlap of input tractography (red) and the atlas (yellow) after registration

wm_quality_control_tract_overlap.py \
  ${atlas} \
  ${inputfolder}/08_registered/01_TractRegistration/${subject}_eddy_fixed_SlicerTractography/output_tractography/${subject}_eddy_fixed_SlicerTractography_reg.vtk \
  ${outputfolder}/QC_03_overlapPostRegistration/${subject}/
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 4 OF X        | OPTIONAL TO RUN / REVIEW
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/04_clusterFromAtlas
#Description:        Creates n=800 fiber clusters, before outliers have been removed (all grey, and 6 views available)   
#Note:               Note that the wm_cluster_from_atlas.py script creates jpgs in 02_FiberClustering/InitialClusters/
#Time:               Long

wm_quality_control_tractography.py \
  $inputfolder/08_registered/02_FiberClustering/InitialClusters/${subject}_eddy_fixed_SlicerTractography_reg/ \ 
  $outputfolder/QC_04_clusterFromAtlas/${subject}
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 5 OF X       | OPTIONAL TO RUN / REVIEW
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/05_noOutliers
#Description:        Creates n=800 fiber clusters, after outliers have been removed (all grey, and 6 views available)   
#Time:               Long

wm_quality_control_tractography.py \
  $inputfolder/08_registered/02_FiberClustering/OutlierRemovedClusters/${subject}_eddy_fixed_SlicerTractography_reg_outlier_removed/ \
  $outputfolder/QC_05_noOutliers/${subject}
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 6 OF X       
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/06_tracts
#Description:        Creates n=41 anatomical tracts, after outliers have been removed (all grey, and 6 views available)   
#Time:               Long

wm_quality_control_tractography.py \
  $inputfolder/08_registered/03_AnatomicalTracts/${subject}/ \ 
  $outputfolder/QC_06_AnatomicalTracts
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 7 OF X       
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  NA (run interactively)
#Description:        To find outliers in measurements (and issues like different headeers

wm_quality_control_cluster_measurements.py \
  $inputfolder/08_registered/04_DiffusionMeasurements/ \
  -outlier_std 3

#We can also extract and visualize a single cluster across multiple subjects!
wm_extract_cluster.py 170 all_subjects_clusters cluster_170 #this extracts
#then, run wm_quality_control

#We can also view this bundle / tracts across subjects
wm_create_mrml_file.py tract_directory/

#We can also create an average tract. See https://github.com/SlicerDMRI/whitematteranalysis/wiki/3)-Visualization-of-Clustered-Tracts





#Note: if running remotely, need to allow ssh connection to open up another window:
#xvfb-run -s “-screen 0 640x480x24 +iglx” wm_quality_control_tractography.py $input_1 $output_1/
#see issue here: https://github.com/TIGRLab/admin/issues/1820

#As indicated above, this script can be modified to interrogate the outputs after each of the 6 processing steps in 07_applyAtlas: 
#RegisterToAtlas 
#ClusterFromAtlas
#OutliersPerSubject
#ClusterByHemisphere
#AppendClusters
#FiberMeasurements
