#!/usr/bin/env perl
#--------------------------------------------------------------------------
# control_file_gen.pl
#

# This script uses the template fort.15 file and the ATCF formatted fort.22
# file as input and produces a fort.15 file as output. The name of the template
# file and the fort.22 file to be used as input must be specified on the
# command line. 
#
# It optionally accepts the coldstarttime (YYYYMMDDHH24), that is, the 
# calendar time that corresponds to t=0 in simulation time. If it is 
# not provided, the first line in the fort.22 file is used as the cold start 
# time, and this time is written to stdout.
#
# It optionally accepts the time in a hotstart file in seconds since cold
# start.
#
# If the time of a hotstart file has been supplied, the fort.15 file 
# will be set to hotstart.
#
# It optionally accepts the end time (YYYYMMDDHH24) at which the simulation
# should stop (e.g., if it has gone too far inland to continue to be 
# of interest).
#
# If the --name option is set to nowcast, the RNDAY will be calculated such 
# that the run will end at the nowcast time.
#
# The --dt option can be used to specify the time step size if it is 
# different from the default of 3.0 seconds. 
#
# The --bladj option can be used to specify the Boundary Layer Adjustment
# parameter for the Holland model (not used by the asymmetric wind vortex
# model, NWS=9.
#
# The NHSINC will be calculated such that a hotstart file is always generated
# on the last time step of the run.
#
# usage:
#   %perl control_file_gen.pl [--cst coldstarttime] [--hst hotstarttime]
#   [--dt timestep] [--nowcast] [--controltemplate templatefile] < storm1_fort.22 
#
#--------------------------------------------------------------------------
# Copyright(C) 2006, 2007, 2008, 2009 Jason Fleming
# Copyright(C) 2006, 2007 Brett Estrade
# 
# This file is part of the ADCIRC Surge Guidance System (ASGS).
# 
# The ASGS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ASGS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#--------------------------------------------------------------------------
#
$^W++;
use strict;
use Getopt::Long;
use Date::Pcalc; 
use Cwd;
#
my @TRACKS = (); # should be few enough to store all in an array for easy access
my $controltemplate;
my $metfile;
my $coldstarttime;
my $hotstarttime;
my $endtime;
my $dt=3.0; 
my $bladj=0.9;
my $name;
my $stormname;
my $tau=0; # forecast period
my $dir=getcwd();

GetOptions("controltemplate=s" => \$controltemplate,
           "metfile=s" => \$metfile,
           "name=s" => \$name, 
           "cst=s" => \$coldstarttime,
           "endtime=s" => \$endtime,
           "dt=s" => \$dt,
           "bladj=s" => \$bladj, 
           "hst=s" => \$hotstarttime);
#
# open template file for fort.15
open(TEMPLATE,"<$controltemplate") || die "ERROR: Failed to open the fort.15 template file $controltemplate for reading.";
#
# open output control file
open(STORM,">fort.15") || die "ERROR: Failed to open the output control file $dir/fort.15.";
print STDOUT "INFO: The output fort.15 file will be written to the directory $dir.\n"; 
#
# open met input file
open(METFILE,"<$metfile") || die "ERROR: Failed to open meteorological (ATCF-formatted) fort.22 file $metfile for reading.";
#
# Build track list
#
while (<METFILE>) {
  chomp($_);
  my @tmp = ();
  # split and remove any spaces
  foreach my $item (split(',',$_)) {
    $item =~ s/\s*//g;
    push(@tmp,$item);
  }
  # 2d array of arrays; [@tmp] creates an anon array in each element of @TRACK
  push(@TRACKS,[@tmp]); 
}
#
# get name - reverse @TRACKS, and get name from first "BEST" track encountered
my $track;
foreach $track (reverse(@TRACKS)) {
  if (@{$track}[4] =~ m/BEST/) {
    if ( defined $track->[27] ) {
       $stormname = $track->[27];
    } else {	 
       printf STDERR "WARNING: The name of the storm does not appear in the hindcast.\n";
       $stormname = "STORMNAME";
    }
    last;
  }
}
#
# get coldstart time
my $cstart;
unless ( $coldstarttime ) {
   # loop through tracks, find first forecast line, use this to find 
   # last hindcast line 
   $cstart = @{$TRACKS[0]}[2];
   print $cstart; # write cold start time to stdout for use in later runs
} else {
   $cstart = $coldstarttime;
}
# convert hotstart time (in days since coldstart) if necessary
if ( $hotstarttime ) {
   $hotstarttime = $hotstarttime/86400.0;
}
# get end time
my $end;
# for a nowcast, end at the beginning of the offical forecast
if ( $name eq "nowcast" ) { 
   foreach $track (@TRACKS) {
      if ( @{$track}[4] =~ m/OFCL/) {
         $end = $track->[2];
         printf(STDERR "INFO: New nowcast time is $end.\n");
         last;
      }
   } 
} elsif ( $endtime ) {
   # if this is not a nowcast, and the end time has been specified, end then
   $end = $endtime
} else {
   # this is not a nowcast; end time was not explicitly specified, 
   # get end time based on either 
   # 1. running out of fort.22 file or 
   # 2. two or more days inland
   my $ty;  # level of tropical cyclone development
   my $now_inland; # boolean, 1 if TY is "IN"
   my $tin; # time since the first occurrence of TY as "IN"
   my $tin_year;
   my $tin_mon;
   my $tin_day;
   my $tin_hour;
   my $tin_min;
   my $tin_sec;
   my $tin_tau; # forecast period at first occurrence of TY as "IN"
   my $c_year;  # time of line currently being processed
   my $c_mon;
   my $c_day;
   my $c_hour;
   my $c_min;
   my $c_sec;
   my $ddays;
   my $dhrs;
   my $dsec; # difference btw time inland and time on current line
   foreach $track (@TRACKS) {
#     my $lat = substr(@{$track}[6],0,3); # doesn't work if only 2 digits
     #@{$track}[6] =~ /[0-9]*/;
     $_ = @{$track}[6];
     /([0-9]*)/;
     $end = $track->[2];
     $tau = $track->[5];
     $ty = @{$track}[10];
     if ( $ty eq "IN" and (not $now_inland) ) {
        $now_inland = 1;
        $tin = @{$track}[2]; # time at first occurrence of "IN" (inland) 
        $tin =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
        $tin_year = $1;
        $tin_mon = $2;
        $tin_day = $3;
        $tin_hour = $4;
        $tin_min = 0;
        $tin_sec = 0;
        $tin_tau = @{$track}[5]
     }
     if ( $now_inland ) { 
        $end =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
        $c_year = $1;
        $c_mon = $2;
        $c_day = $3;
        $c_hour = $4;
        $c_min = 0;
        $c_sec = 0;
        #
        # get difference between first occurrence of IN (inland)
        # and the time on the current track line
        ($ddays,$dhrs,$dsec) 
           = Date::Pcalc::Delta_DHMS(
                $tin_year,$tin_mon,$tin_day,$tin_hour,$tin_min,$tin_sec,
                $c_year,$c_mon,$c_day,$c_hour,$c_min,$c_sec);
        my $time_inland = $ddays + $dhrs/24 + $dsec/86400 + ($tau-$tin_tau)/24;
        if ( $time_inland >= 2.0 ) {
           last; # jump out of loop with current track as last track
        }
     }
   }
}
#
$cstart=~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
my $cs_year = $1;
my $cs_mon = $2;
my $cs_day = $3;
my $cs_hour = $4;
my $cs_min = 0;
my $cs_sec = 0;
#
$end =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
my $e_year = $1;
my $e_mon = $2;
my $e_day = $3;
my $e_hour = $4;
my $e_min = 0;
my $e_sec = 0;
#
# get difference btw cold start time and end time
my ($days,$hours,$seconds) 
   = Date::Pcalc::Delta_DHMS(
      $cs_year,$cs_mon,$cs_day,$cs_hour,$cs_min,$cs_sec,
      $e_year,$e_mon,$e_day,$e_hour,$e_min,$e_sec);
# RNDAY is diff btw cold start time and end time
# RNDAY is one time step short of the total time to ensure that we 
# won't run out of storm data.
my $RNDAY = $days + $hours/24 + ($seconds-$dt)/86400; 
#
# If RNDAY is less than two timesteps, make sure it is at least two timesteps. 
# This can happen if we start up from a fort.22 that has only one BEST line,
# i.e., it starts at the nowcast. RNDAY would be zero in this case, except 
# our algorithm actually stops one ts short of the full time, so RNDAY is
# actually negative in this case. ADCIRC needs at least two timesteps from 
# coldstart to create a valid hotstart file.
my $runlength = $RNDAY*86400.0;
if ( $hotstarttime ) {
   $runlength-=$hotstarttime;
}
my $min_runlength = 2*$dt;
if ( $runlength < $min_runlength ) { 
   $RNDAY=$min_runlength/86400.0;
   unless ( $hotstarttime eq "" ) {
      $RNDAY+=($hotstarttime/86400.0);
   }
}
#
# if this is an update from hindcast to nowcast, calculate the hotstart 
# increment so that we only write a single hotstart file at the end of 
# the run. If this is a forecast, don't write a hotstart file at all.
my $NHSINC = int($runlength/$dt);
my $NHSTAR;
if ( $name eq "nowcast" ) {
   $NHSTAR = 1;
} else {
   $NHSTAR = 0;
}
while(<TEMPLATE>) {
    # if we are looking at the first line, fill in the name of the storm
    s/%StormName%/$stormname/;
    # if we are looking at the DT line, fill in the time step (seconds)
    s/%DT%/$dt/;
    # if we are looking at the RNDAY line, fill in the total run time (days)
    s/%RNDAY%/$RNDAY/;  
    # fill in the correct value of IHOT -- we always look for a fort.68
    # file, and since we only write one hotstart file during the run, we
    # know we will always be left with a fort.67 file.
    if ( $hotstarttime ) {
       s/%IHOT%/68/;
    } else { 
       s/%IHOT%/0/;
    }
    # fill in the timestep increment that hotstart files will be written at
    s/%NHSINC%/$NHSINC/;
    # fill in whether or not we want a hotstart file out of this
    s/%NHSTAR%/$NHSTAR/;
    # 
    # fill in ensemble name
    s/%EnsembleID%/$name/;
    # Holland parameters -- not used for asymmetric wind model, but perhaps
    # useful for debugging
    s/%HollandParams%/$cs_year $cs_mon $cs_day $cs_hour 1 $bladj/;
    print STORM $_;
}
close(TEMPLATE);
close(STORM);
close(METFILE);
