#!/usr/bin/env python
import nibabel as nib
import numpy as np
import pandas as pd
import os
from glob import glob

#We need to convert all of the eddy-corrected images to 'ints', and remove the decimal place
#The reason for this is that dtiprep doesn't allow for decimal places that eddy produces???

#Notes to self:
#If running in the terminal, module load Python 3+, and then run in ipython
#If getting errors about indents, may be because Python doesn't like spaces in the terminal
#Because of difficulties installing dependencies in my own Python environment, I will use the lab's Python 
#This code takes a bit of time to run -- about 6 seconds per participant -- so about an hour for SPINS 

#module load python/3.8.1
#ipython

#make the directory for the output
mkdir -p /projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT

input_dir   = "/projects/ncalarco/thesis/SPINS/Slicer/data/01_dmriprep"
output_dir  = "/projects/ncalarco/thesis/SPINS/Slicer/data/03_dmriprep_INT"
sublist = open("/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/03_sublist.txt", "r")
SID = sublist.readlines()
SID = [i.replace('\n', '') for i in SID]

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
