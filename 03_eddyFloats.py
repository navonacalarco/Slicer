#!/usr/bin/env python

####################################################################################
#Name:         03_eddyFloats.py

#Last updated: 2020-03-17

#Description:  Remove decimal places from eddy-corrected images

#Submission:   I run interactively in ipython (avoid spacing issues with python)

#Notes: 
               #We need to convert all of the eddy-corrected images to 'ints', 
               #i.e., remove the decimal place, as dtiprep doesn't allow for floats (???)
               #This code takes a bit of time to run -- about 6 seconds per participant -- so about an hour for SPINS  

####################################################################################

#modules
module load python/3.8.1

#use ipython interactively
ipython

#import packages
import nibabel as nib
import numpy as np
import pandas as pd
import os
from glob import glob

#make the directory for the output
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT

#define directory variables
input_dir   = "/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"
output_dir  = "/projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT"

#set up subject list
sublist = open("/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt", "r")
SID = sublist.readlines()
SID = [i.replace('\n', '') for i in SID]

#run conversion
for i in SID:
    print(i)
    check_exists = os.path.join(output_dir, i, i + '_eddy_fixed.nii.gz')

    if not os.path.isfile(check_exists):
        os.makedirs(os.path.join(output_dir, i))
        sub_image = glob(os.path.join(input_dir, i, '*', '*', '*desc-brainsuite_dwi.nii.gz'))[0]

    if os.path.isfile(sub_image):
        img = nib.load(sub_image)
        hdr = img.header
        new_data = np.copy(img.get_data())
        new_dtype = np.int16
        new_data = new_data.astype(new_dtype)
        img.set_data_dtype(new_dtype)

        new_image = nib.Nifti1Image(new_data, img.affine, header=hdr)
        print(new_image.get_data_dtype())

        nib.save(new_image, check_exists)
