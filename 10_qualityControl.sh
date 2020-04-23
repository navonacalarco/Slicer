#!/bin/bash
#SBATCH --array=18268
#SBATCH --cpus-per-task=1
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/SlicerQC/SlicerQC_%A_%a.err
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/SlicerQC/SlicerQC_%A_%a.out
#SBATCH --job-name=SlicerQC2_%j

#This script runs whitematteranalysis automated QC 
#QC should be run at least twice: after tractography (initial), and after end results (final); however, if problems are found, it can also be run after each of the 6 major steps delinated in https://github.com/navonacalarco/Slicer/blob/master/07_applyAtlas.sh
#It is very quick! However, we discovered that the whitematteranalysis script cannot be run in parallel
#If preferred once working, we can send our log files (error/output) to /dev/null because we don't need to review
#More info about the whitematter analysis QC script is here: https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md

#Purge modules in my environment -- affecting queue...
module purge

#Reload required modules
module load python/2.7.8-anaconda-2.1.0
module load python-extras/2.7.8
module load slicer/0,nightly #needs to be loaded first(?)
module load whitematteranalysis/2018-07-19

##################################################################################
#Preparatory work
#We need to do some preparatory work, as the script runs on directories, not files

# STEP 1: move data required for all-subject review
# We need data to a single directory, so easier to keep track
# mkdir /projects/ncalarco/thesis/SPINS/Slicer/data/09_vtkRegisteredOnly
# cd /projects/ncalarco/thesis/SPINS/Slicer/data/08_registered/RegisterToAtlas
# find . -name '*_SlicerTractography_reg.vtk' -exec cp -t /projects/ncalarco/thesis/SPINS/Slicer/data/09_vtkRegisteredOnly/ {} +  #take a while to find and move
# ls /projects/ncalarco/thesis/SPINS/Slicer/data/09_vtkRegisteredOnly | wc #436

# STEP 2: move data required for all tract-by-subject review
# these files are in /projects/ncalarco/thesis/SPINS/Slicer/data/08_registered/Regions_Subjects_Files_Nested and also /Region_SubjectFile_Flattened
# see Kevin's notes in `forNavona.txt`
# for dir in *; do echo mkdir -vp ${dir/.vtk/}; echo mv -v ${dir} ${dir/.vtk/}; done
# wm_quality_control_tractography.py expects a directory, so here's a
# thing we did to ensure that each vtk file was in its own unique
# directory, for parallelisation purposes

# STEP 3: make a qclist.txt THIS IS NOT NEEDED ANYMORE
# find /projects/ncalarco/thesis/SPINS/Slicer/data/08_registered/AppendClusters -type d > /projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/04_qclist.txt

##################################################################################

export qclist="/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/04_qclist.txt" #We don't actually need this anymore....

index() {
   head -n $SLURM_ARRAY_TASK_ID $qclist \
   | tail -n 1
}

#fancy text manipulation to find directory and subject names
export outpath=$(echo `index` | rev | cut -d '/' -f -2 | rev | cut -d '_' -f 2-)
export subname=$(echo ${outpath} | cut -d '/' -f 1)

#make directories for QC data DON'T NEED THIS
#mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_01_registeredToAtlas/${subname}

#define variables
inputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/
outputfolder=/projects/ncalarco/thesis/SPINS/Slicer/data/10_QC
atlas=/projects/ncalarco/thesis/SPINS/Slicer/atlas/ORG-800FC-100HCP-1.0/atlas.vtp

#make directory
mkdir -p $outputfolder

#QC tractography across all participants (catch early errors in tractography)
#expected output: html; whole brain, 6 views, all grey
wm_quality_control_tractography.py $inputfolder/09_vtkRegisteredOnly $outputfolder/QC_01_tractography

#QC registration of overlap between tractography and atlas _before_ registration 
#expected output: jpg, with atlas in yellow, tractography in red
wm_quality_control_tract_overlap.py $atlas $inputfolder/09_vtkRegisteredOnly $outputfolder/QC_02_overlapBeforeRegistration

#QC registration of overlap between tractography and atlas _after_ registration (make sure tractography is now in the same space as the atlas)
#expected output: jpg, with atlas in yellow, tractography in red
wm_quality_control_tract_overlap.py $atlas $inputfolder/09_vtkRegisteredOnly/01_TractRegistration $outputfolder/QC_03_overlapAfterRegistration

#QC tractography fiber clustering
#expected output: whole brain, but fibers have been clustered in n=800. folders per cluster and per view. all grey.
wm_quality_control_tractography.py $inputfolder/08_registered/FiberClustering/InitialClusters/${subname}/ $outputfolder/QC_04_clusterFromAtlas #won't work?... check output

#QC tractography after outlier removal
#expected output: as above whole brain, but fibers have been clustered in n=800. folders per cluster and per view. all grey.
wm_quality_control_tractography.py $inputfolder/08_registered/FiberClustering/OutlierRemovedClusters/${subname}/ $outputfolder/QC_05_FiberCluster-OutlierRemoved

#QC tractography of anatomical tracts
wm_quality_control_tractography.py $inputfolder/08_registered//AnatomicalTracts/ $outputfolder/QC_06_AnatomicalTracts


#Note: if running remotely, need to allow ssh connection to open up another window:
#xvfb-run -s “-screen 0 640x480x24 +iglx” wm_quality_control_tractography.py $input_1 $output_1/

#As indicated above, this script can be modified to interrogate the outputs after each of the 6 processing steps in 07_applyAtlas: 
#RegisterToAtlas 
#ClusterFromAtlas
#OutliersPerSubject
#ClusterByHemisphere
#AppendClusters
#FiberMeasurements
