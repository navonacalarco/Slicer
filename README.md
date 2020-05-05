<p align="center">__README `Slicer`__</p>

__Description.__ This repo primarily contains scripts to perform whole-brain deterministic tractography on single-shell data, using `3D Slicer` and `whitematteranalysis` software. Specifically, the directory contents are as follows:

1. __`scripts.`__ These 9 scripts take in the lab's preprocessed DWI data, and run all subsequent steps ultimately required for tractography. The scripts should, more or less, be run sequentially: most rely on outputs made in prior scripts. 
2. __`exampleData.`__ The example .vtk file is from the [whitematteranalysis tutorial](https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md). It was computed from one HCP healthy young adult subject, using UKF -- nonetheless, it is sufficient for running code tests (despite the fact we are not using UKF). It is not referenced by any scripts.
3. __`visualization.`__ The glassbrain.vtk file is from [Madan, 2015](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4648228/). It provides a pretty anatomical background for visualizing tracts. It is not referenced by any scripts.

__Requirements__:
The scripts require (i) input data to be in BIDS format, and (ii) access to the [ORG atlas](https://github.com/SlicerDMRI/ORG-Atlases). 

__System and software info__:
I have run all scripts on `kimel`. All software was accessed via the module system. Versions are denoted at the top of each script -- in most cases, the software is the 'latest' as of 05-2020.

__Important links__:  
[ORG atlas](https://github.com/SlicerDMRI/ORG-Atlases)  
[whitematteranalysis wiki](https://github.com/SlicerDMRI/whitematteranalysis/wiki)  
[whitematteranalysis tutorial](https://github.com/SlicerDMRI/whitematteranalysis/blob/master/doc/subject-specific-tractography-parcellation.md)
