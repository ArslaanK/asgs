#!/bin/bash
#
# Robert J Weaver
# UNC-CH IMS
# rjweaver@email.unc.edu
# 06/2009 
#  
CONFIG=$1
ADVISDIR=$2
OUTPUTDIR=$3
STORM=$4
YEAR=$5
ADVISORY=$6
HOSTNAME=$7
ENSTORM=$8
GRIDFILE=$9 
#
cd $ADVISDIR/$ENSTORM
#  	echo $ADVISDIR/$ENSTORM
# grab configuration from main ASGS configuration script
. ${CONFIG}
#
# This script will run the KMZ and GIS shapefile generator 
# and make a JPG of the maxele file
#
# to use copy this script where you would like the output to be generated,
# follow the instructions on how to set up the path definitions and 
# variable definitions in this file and in the Renci config file
# and be sure the grid you are using is properly placed in the grid folder 
# and fully decomposed so that it can be used by the GMT functions.
# 
# if your grid has not already been decomposed, you must do this first!
# there is a program in the grids folder ./grd2gmt.x
# here is an example of how to run it for our purposes:
#  ./grd2gmt.x sl15v3_2007_r10.grd sl15v3_2007_r10
# this will produce 4 files named 
# sl15v3_2007_r10.gmt.bnd.xy
# sl15v3_2007_r10.gmt.tri
# sl15v3_2007_r10.gmt.xy
# sl15v3_2007_r10.gmt.xyz
# 
# now you are ready to continue
#
# First set path to the POSTPROC_KMZGIS directory
#
POSTPROC_DIR=$OUTPUTDIR/POSTPROC_KMZGIS
#echo $POSTPROC_DIR
#
# add location of KMZ scripts to PATH 
# This should be fine unless locations were really changed
#
export PPDIR=$POSTPROC_DIR/RenciGETools-1.0/src
#echo $PPDIR
#
# now set definitions needed for the KMZ generator
#
# .. KMZ .. 
#
# THERE ARE 2 FILES TO EDIT PRIOR TO RUNNING KMZ SCRIPTS

# .......
# 1 must edit $PPDIR/config_simple_gmt_pp.sh
# .......

# This is the main configuration file for the KMZ scripts.
# in this file you must indicate the computer on which you
# are trying to run, AND the bounding box for your output.
# the varable names are :
#
# TARGET and BOX
#
# For TARGET, be sure to double check the paths to the indicated software packages.
# These are all required so if they do not currently exist, you will need to install them.
# 
# If you do not see your computer or the region of your interest,
# then simply add a case using the existing cases as a template.

# .........
# 2 now modify this script
# .........


# now declare the variables to input into script
#
# This is the meat of what needs to be defined.
# 
# INPUTFILE : need to identify location of input data file
# GRIDPREFIX : need to identify which grid set will be used
# OUTPUTPREFIX : set output filename prefix
# NUMLAYER : number of layers to the KMZ file for street level resolution we recommend 4 layers
# On topsail.unc.edu 4 layers for a 270000 node grid took 14 minutes.
# to test the script use only 1 layer.
  
KMZLOGFILE=$ADVISDIR/$ENSTORM/kmz.log # log file for kmz info and errors
INPUTFILE=$ADVISDIR/$ENSTORM/maxele.63
#    INPUTFILE=$ADVISDIR/$ENSTORM/maxwvel.63
GRIDPREFIX=`basename $GRIDFILE .grd`
OUTPUTPREFIX=${STORM}_${YEAR}_${ENSTORM}_${ADVISORY}
NUMLAYER=3
# create track line and points if available
perl $PPDIR/make_track_files.pl >> $KMZLOGFILE 2>&1
#
$PPDIR/adc_max_simple_plot_gmt.sh -f $INPUTFILE -g $GRIDPREFIX -p $OUTPUTPREFIX -n $NUMLAYER >> $KMZLOGFILE 2>&1  &

# exit 0
# #####################################################
#
# now set definitions for GIS generator
#
# .. GIS ..
# 
# For the GIS shapefiles we need the full poath name of the grid that your are running
# and we will use the same file as above for the input file 
# (you of course can change this as you desire)
# The program name for the script is actoshape

# excecute config file to get bounds for output box (full coastline)
# and location (Path) to grid files
source $PPDIR/config_simple_gmt_pp.sh
# OR define your own bounds 
#  NORTH=30.5
#  SOUTH=28.5
#  EAST=-88.5
#  WEST=-90.5
#
echo 
if [ -e $GRDFILES/$GRIDPREFIX.grd ]
then
   INPUTGRID=$GRDFILES/$GRIDPREFIX.grd
elif [ -e $GRDFILES/$GRIDPREFIX.14 ]
then
   INPUTGRID=$GRDFILES/$GRIDPREFIX.14
else
   echo "cannot find, $GRDFILES/$GRIDPREFIX.grd ,or, $GRDFILES/$GRIDPREFIX.14 "
   exit 1
fi
GISLOGFILE=$ADVISDIR/$ENSTORM/gis.log # log file for gis-related info/errors
echo "starting Java script ArcGIS POST PROC", $WEST, $SOUTH, $EAST, $NORTH
echo $INPUTGRID, $INPUTFILE,$OUTPUTPREFIX.shp

 java -Xmx2048M -jar $POSTPROC_DIR/actoshape/actoshape.jar \
  --box $WEST $SOUTH $EAST $NORTH \
  --clipcoast 100 \
  $INPUTGRID \
  $INPUTFILE \
  $OUTPUTPREFIX.shp >> $GISLOGFILE 2>&1  &

# #####################################################
#
# now set definitions for JPG generator
#
# .. JPG ..
# Use the same NSEW as above (may create a bad plot)
# OR define your own bounds
#  NORTH=30.5
#  SOUTH=27.5
#  EAST=-88.5
#  WEST=-90.5

#
#  Usage Example:
#   perl make_JPG.pl --storm 01 --year 2006 --adv 05 --n 30.5 --s 28.5 --e -88.5 --w -90.5 --outputprefix 01_2006_nhcconsensus_05
  
# for now must create this in the sharedirectory on Ranger, so make it so on every machine
cd $POSTPROC_DIR/FigGen/
#
ln -fs $INPUTFILE ./
ln -fs $ADVISDIR/$ENSTORM/fort.14 ./ 
#
 perl make_JPG.pl --outputdir $POSTPROC_DIR --gmthome $GMTHOME --storm ${STORM} --year ${YEAR} --adv $ADVISORY --n $NORTH --s $SOUTH --e $EAST --w $WEST --outputprefix $OUTPUTPREFIX
    
#    cd ./Temp
#    ln -fs $GRDFILES/$GRIDPREFIX.gmt.bnd.xy ./fort.14.bnd.xy
#    ln -fs $GRDFILES/$GRIDPREFIX.gmt.tri ./fort.14.tri
#    ln -fs $GRDFILES/$GRIDPREFIX.gmt.xyz ./fort.14.gmt.xyz
#    cd ../
./FigureGen32.exe >> $ADVISDIR/$ENSTORM/jpg.log 2>&1  &
#
while [ ! -e $POSTPROC_DIR/FigGen/$OUTPUTPREFIX.jpg ]; do
   sleep 60
done
sleep 60
mv ./$OUTPUTPREFIX.jpg  $ADVISDIR/$ENSTORM/$OUTPUTPREFIX.jpg
rm -f $POSTPROC_DIR/FigGen/fort.14
rm -f $POSTPROC_DIR/FigGen/max*.63
rm -f $POSTPROC_DIR/FigGen/$OUTPUTPREFIX.ps
#
# now go back to the advisory directory
cd $ADVISDIR/$ENSTORM/
# ..   ..
#
# Use this section of the script to move the files where you want them
while [ ! -e $OUTPUTPREFIX.kmz ]; do
   sleep 60
done
while [ ! -e $OUTPUTPREFIX.shp ]; do
   sleep 60
done
sleep 60
mkdir  $OUTPUTPREFIX-KMZ_GIS_files
mv $OUTPUTPREFIX.* $OUTPUTPREFIX-KMZ_GIS_files
tar -czf $OUTPUTPREFIX-KMZ_GIS.tar.gz $OUTPUTPREFIX-KMZ_GIS_files
rm -rf $OUTPUTPREFIX-KMZ_GIS_files $OUTPUTPREFIX*.png
###
exit 0
