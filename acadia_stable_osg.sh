#!/bin/bash

DURATION=6

export JUGGLER_TAG=4.0-acadia-stable

# HEPMC2
export USEHEPMC3=false
scripts/submit_csv.sh templates/osg.in hepmc3 DIS/NC/DIS_NC.csv ${DURATION}
scripts/submit_csv.sh templates/osg.in hepmc3 DIS/CC/DIS_CC.csv ${DURATION}

# HEPMC3
export USEHEPMC3=true


# SINGLE
scripts/submit_csv.sh templates/osg.in single SINGLE/SINGLE_3to50deg.csv ${DURATION}
scripts/submit_csv.sh templates/osg.in single SINGLE/SINGLE_45to135deg.csv ${DURATION}
scripts/submit_csv.sh templates/osg.in single SINGLE/SINGLE_130to177deg.csv ${DURATION}
