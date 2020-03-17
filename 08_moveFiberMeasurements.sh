#this script is used to rename and move the output csvs from Slicer tractography, to a single directory, for analysis in R. 

destfolder=/projects/ncalarco/thesis/SPINS/Slicer/txt_outputs/05_FiberMeasurements_csvs

for subject in /projects/ncalarco/thesis/SPINS/Slicer/data/08_registered/FiberMeasurements/*;
do
    subid=$(basename $subject)
    for subdir in tracts_commissural tracts_left_hemisphere tracts_right_hemisphere;
    do
        cp $subject/$subdir/$subid.csv $destfolder/${subdir}_$subid.csv
    done
done
