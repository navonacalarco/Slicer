#!/bin/bash
#SBATCH --array=18268
#SBATCH --cpus-per-task=1
#SBATCH --error=/projects/ncalarco/thesis/SPINS/Slicer/logs/SlicerQC/SlicerQC_%A_%a.err
#SBATCH --output=/projects/ncalarco/thesis/SPINS/Slicer/logs/SlicerQC/SlicerQC_%A_%a.out
#SBATCH --job-name=SlicerQC2_%j

#This script runs whitematteranalysis automated QC on (1) first-step tractography across all subjects, and (2) final tractography per subject (all tracts)
#It is very quick! However, we discovered that the whitematteranalysis script cannot be run in parallel
#If preferred once working, we can send our log files (error/output) to /dev/null because we don't need to review

# Information about the whitematter analysis QC script is here:
# https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md
# We have the script stored in opt/quarantine

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

# STEP 3: make a qclist.txt
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

#make directories for QC data
#mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_01_registeredToAtlas/${subname}
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_02_finalTracts/tracts_commissural
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_02_finalTracts/tracts_right_hemisphere
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_02_finalTracts/tracts_left_hemisphere


#Run across all participants (catch early errors / registration errors)
#wm_quality_control_tractography.py /projects/ncalarco/thesis/SPINS/Slicer/data/09_vtkRegisteredOnly "/projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_01_registeredToAtlas"

#Run on across each tract for all participants, with outliers removed
wm_quality_control_tractography.py "/projects/ncalarco/thesis/SPINS/Slicer/data/08_registered/Region_SubjectFile_Flattened/tracts_commissural" "/projects/ncalarco/thesis/SPINS/Slicer/data/10_QC/QC_02_finalTracts/tracts_commissural"
