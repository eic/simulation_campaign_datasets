#!/bin/bash
set -Eu # no pipefail to allow head to cut pipe
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

out=${1?Specify output}
file=${2?Specify filename}
ext=${3?Specify extension}
nevents=${4:-} # allow empty
n_lines_per_event=${5:-} # allow empty

s3prefix="S3/eictest/EPIC/EVGEN"
s3https="s3https://eics3.sdcc.bnl.gov:9000/eictest/EPIC/EVGEN"
xrootd="root://dtn-eic.jlab.org//work/eic2/EPIC/EVGEN"

if [[ "${ext}" =~ ^hepmc\.gz$ ]] ; then
  GUNZIP=(gunzip -c)
else
  GUNZIP=(cat)
fi

# if nevents not known
if [[ "${nevents}" == 0 ]] ; then
  # count events
  nevents=$(mc cat ${s3prefix}/${s3file} | ${GUNZIP[@]} | grep ^E | wc -l)
fi

# if hepmc3.tree.root file
if [[ "${ext}" =~ ^hepmc3\.tree.root$ ]] ; then
  # get entries from xrootd
  nevents1=$(root -l -b -q ${xrootd}/${file}.${ext} -e 'cout << hepmc3_tree->GetEntries() << endl;' | tail -n1)
  # get entries from S3
  nevents2=$(root -l -b -q ${s3https}/${file}.${ext} -e 'cout << hepmc3_tree->GetEntries() << endl;' | tail -n1)
  # compare
  test ${nevents1} -eq ${nevents2}
  nevents=${nevents1}
  n_lines_per_event=0
fi

# if n_lines_per_event not known
if [ -z "${n_lines_per_event}" ] ; then
  # count events in 10k lines
  n_events_10k=$(mc cat ${s3prefix}/${s3file} | ${GUNZIP[@]} | head -n 10000 | grep ^E | wc -l)
  n_lines_per_event=$((10000/n_events_10k))
fi

# output
echo "$file,$ext,$nevents,$n_lines_per_event" | tee -a "${out}"
