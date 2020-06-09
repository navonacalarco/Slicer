#!/bin/bash -l

####################################################################################
#Name:         #10_QC-fiberMeasurement.sh

#Last updated: #2020-04-27

#Description:  #Runs quality control on all steps in 08_applyAtlas.sh

#Submission:   #sbatch (remember to change the array to reflect number of participants)

#Notes:        #These scripts have positional arguments, so don't change order
               #These scripts call the whitematteranalysis package (cf. Slicer). This means that the commands can be run as is on a Mac (!); no need to change path
               #Documentation here: https://github.com/SlicerDMRI/whitematteranalysis/wiki/2c)-Running-the-Clustering-Pipeline-to-Cluster-a-Single-Subject-from-the-Atlas
               #Tutorial here: https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md
               #To see the help file, type python `/opt/quarantine/whitematteranalysis/2018-07-19/build/bin/SCRIPTNAME.py` -h (uses argparse)
               #Note: to visualize .jpg images and share via Rpubs, will need to downsample. I have used ImageMagick: `mogrify -strip -interlace Plane -gaussian-blur 0.05 -quality 75% *.jpg`
               
#File organization: 
#               Note also that some of the wma QC scripts appear to want input files in a flat directory, whereas others assume a stacked/directory structure.
#               To accomodate this without complicating the code too much, I've made two copies of the input files: one flat, one stacked
#               The flat files are in the original /projects/ncalarco/thesis/Slicer/SPINS/data/07_vtk directory
#               The stacked files have are in /projects/ncalarco/thesis/Slicer/SPINS/data/10_QC/QC_00_rawVTK
#               They were made simply by copying the 07_vtk, and then creating an eponymous directory for each file: 
#               `for x in ./*.vtk; do; mkdir "${x%.*}" && mv "$x" "${x%.*}"; done`
####################################################################################

#load required modules
module load python/3.6.3-anaconda-5.0.1
module load slicer/0,nightly 
module load whitematteranalysis/2020-04-24

#define environment variables
inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/07_vtk
outputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/10_QC
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtp

#make output folder
mkdir -p $outputfolder

#subject list
sublist=`cat /projects/ncalarco/thesis/SPINS/Slicer/outputs/03_sublist.txt`


#--------------------------------------------------------------------------------------------------------------------
#STEP 1 OF 8
#--------------------------------------------------------------------------------------------------------------------

#Directory created:   10_QC/QC_01_tractography
#Description:         QC tractography across all participants (catch early errors in tractography)
#Notes:               Expected output: html; whole brain, 6 views, all grey
#Time:                Fast

for subject in $sublist; do
 inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_00_rawVTK/${subject}_SlicerTractography
 wm_quality_control_tractography.py \
   ${inputfolder} \
   ${outputfolder}/QC_01_tractography
done
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 2 OF 8
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/QC_02_overlapPreRegistration
#Description:        Show overlap of input tractography (red) and the atlas (yellow) before registration

while read subject; do
wm_quality_control_tract_overlap.py \ 
  ${atlas} \
  ${inputfolder}/${subject}_SlicerTractography.vtk \
  ${outputfolder}/QC_02_overlapBeforeRegistration/${subject}/
done < ${sublist}

#--------------------------------------------------------------------------------------------------------------------
#STEP 3 OF 8
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/QC_03_overlapPostRegistration
#Description:        Show overlap of input tractography (red) and the atlas (yellow) after registration

for subject in $sublist; do
wm_quality_control_tract_overlap.py \
  ${atlas} \
  ${inputfolder}/08_registered/01_TractRegistration/${subject}_SlicerTractography/output_tractography/${subject}_SlicerTractography_reg.vtk \
  ${outputfolder}/QC_03_overlapPostRegistration/${subject}/
done

#--------------------------------------------------------------------------------------------------------------------
#STEP 4 OF 8        | OPTIONAL TO RUN / REVIEW
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/QC_04_clusterFromAtlas
#Description:        Creates n=800 fiber clusters, before outliers have been removed (all grey, and 6 views available)   
#Note:               Note that the wm_cluster_from_atlas.py script creates jpgs in 02_FiberClustering/InitialClusters/
#Time:               Long

wm_quality_control_tractography.py \
  $inputfolder/08_registered/02_FiberClustering/InitialClusters/${subject}_eddy_fixed_SlicerTractography_reg/ \ 
  $outputfolder/QC_04_clusterFromAtlas/${subject}
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 5 OF 8       | OPTIONAL TO RUN / REVIEW
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/QC_05_noOutliers
#Description:        Creates n=800 fiber clusters, after outliers have been removed (all grey, and 6 views available)   
#Time:               Long

wm_quality_control_tractography.py \
  $inputfolder/08_registered/02_FiberClustering/OutlierRemovedClusters/${subject}_eddy_fixed_SlicerTractography_reg_outlier_removed/ \
  $outputfolder/QC_05_noOutliers/${subject}
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 6 OF 8       
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  10_QC/QC_06_anatomicalTracts
#Description:        Creates n=41 anatomical tracts, after outliers have been removed (all grey, and 6 views available)   
#Time:               Long

wm_quality_control_tractography.py \
  $inputfolder/08_registered/03_AnatomicalTracts/${subject}/ \ 
  $outputfolder/QC_06_anatomicalTracts
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 7 OF 8    NOT WORKING
#--------------------------------------------------------------------------------------------------------------------

#Directory created:  NA (run interactively)
#Description:        To find outliers in measurements (and issues like different headers)

wm_quality_control_cluster_measurements.py \
  $inputfolder/08_registered/04_DiffusionMeasurements \
  -outlier_std 3
  
#--------------------------------------------------------------------------------------------------------------------
#STEP 8 OF 8    OPTIONAL -- INCOMPLETE  
#--------------------------------------------------------------------------------------------------------------------  

#Directory created:  10_QC/09_sharedScene
#Description:        Creates a single .mrml (scene) file combining all input .vtks  -- essentially showing a tract across all participants
#Time:               Short
#Note:               Each .vtk file that is combined in the scene will be represented as a 'node' in the scene file
#                    Need to figure out how to append subject name to 03_AnatomicalTracts and move TOI into separate directory

wm_create_mrml_file.py tract_directory/

