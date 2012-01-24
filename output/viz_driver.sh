#!/bin/sh
INPUT=$1     # fort.22 file used as input
ADVISORY=$2  # used in file names and plot titles
TIMESTEP=$3  # seconds, e.g., 1800.0 # "default" to hit the cycle times
MESHFILE=$4  # fort.14 file name or 0 to autogenerate mesh

ASGSDIR=~/asgs/trunk
ADCIRCDIR=~/adcirc/newvortex/work
PERL5LIB=$ASGSDIR/PERL ; export PERL5LIB

FRAME=0         # "0" for all frames
MYPROC=0        # "0" in serial
#MESHFILE=~/adcirc/examples/parallel_ec95d/coldnetcdf/ec_95d.grd  # "0" to autogenerate mesh
#
DELAY=10
if [ $TIMESTEP = default ]; then
   DELAY=100
fi
#
# clean up pre-existing data and image files, if any
rm -f fort.22 radii_???.ps radialv_???.ps radialp_???.ps page???.gif page???.ps pages???.ps spatial_data_???.d spatial_cycle???.gif montage_geom_???.gif montage*.jpg spatial_data_???.d full_circle_rmaxes_???.d radii_??kt_cycle???.d radialvp_latlon_???.d full_circle_latlon_???.d spatial_data_???.d *.png compass_full_circle_rmaxes_???.d radialvp_???.d montage_geom_fullsize_???.gif montage_geom_???.gif
#
# generate a preprocessed output file
$ADCIRCDIR/aswip -m 2 -w $INPUT
#
# TODO: for parallel execution?
#
# execute frame driver in serial for all frames
$ASGSDIR/output/frame_driver.sh $INPUT $TIMESTEP $ADVISORY $FRAME $MYPROC $ADCIRCDIR $ASGSDIR $PERL5LIB $MESHFILE
#
# make animation out of the montage sequence of images
#convert -loop 0 -delay $DELAY montage_geom_???.gif anim_all_${ADVISORY}.gif
rm anim_${TIMESTEP}_all.mp4
ffmpeg -r 5 -i montage_geom_%03d.jpg anim_${TIMESTEP}_all.mp4