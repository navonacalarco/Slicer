#!/usr/bin/env python

####################################################################################
#Name:         03_eddyFloats.py

#Last updated: 2020-06-06

#Description:  Remove decimal places from eddy-corrected images

#Submission:   I run interactively in ipython (avoid spacing issues with python)

#Notes: 
               #We need to convert all of the eddy-corrected images to 'ints', 
               #i.e., remove the decimal place, as Slicer doesn't allow for floats 
               #This code takes a bit of time to run -- about 6 seconds per participant -- so about an hour for SPINS  
               #Note: ipython is not a module; I have it installed locally on my machine (Franklin)

####################################################################################

#make the directory for the output
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/04_dmriprep_INT

#modules
module load python/3.8.1

#use ipython interactively
ipython

#import packages
import nibabel as nb
import numpy as np
import pandas as pd
import os
from glob import glob

#define directory variables
input_dir = "/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep/*/*/dwi/"
output_dir = "/projects/ncalarco/thesis/SPINS/Slicer/data/04_dmriprep_INT"

#run conversion
brainsuite_files = sorted(glob(f"{input_dir}/*brainsuite_dwi.nii.gz"))
for f in eddy_files:

    base_file = os.path.basename(f).replace("_desc-preproc_dwi.nii.gz", "")
    output_file = os.path.join(output_dir, base_file + "_eddy_fixed.nii.gz")

    if not os.path.isfile(output_file):
        img = nb.load(f)
        data = img.get_fdata().astype(np.int16)
        new_img = nb.Nifti1Image(data, img.affine, img.header)
        new_img.header.set_data_dtype(np.int16)
        new_img.to_filename(output_file)
