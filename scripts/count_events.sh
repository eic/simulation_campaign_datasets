#!/bin/bash
set -Eu # no pipefail to allow head to cut pipe
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

out=${1?Specify output}
file=${2?Specify filename}
ext=${3?Specify extension}
nevents=${4:-} # allow empty
n_lines_per_event=${5:-} # allow empty

if [[ "${ext}" =~ ^hepmc\.gz$ ]] ; then
  GUNZIP=(gunzip -c)
else
  GUNZIP=(cat)
fi

# if nevents not known
if [[ "${nevents}" == 0 ]] ; then
  # count events
  nevents=$(mc cat S3/eictest/EPIC/EVGEN/${file}.${ext} | ${GUNZIP[@]} | grep ^E | wc -l)
fi

# if hepmc3.tree.root file
if [[ "${ext}" =~ ^hepmc3\.tree.root$ ]] ; then
  # get entries
  nevents=$(root -l -b -q root://dtn-eic.jlab.org//work/eic2/EPIC/EVGEN/${file}.${ext} -e 'cout << hepmc3_tree->GetEntries() << endl;' | tail -n1)
fi

# if n_lines_per_event not known
if [ -z "${n_lines_per_event}" ] ; then
  # count events in 10k lines
  n_events_10k=$(mc cat S3/eictest/EPIC/EVGEN/${file}.${ext} | ${GUNZIP[@]} | head -n 10000 | grep ^E | wc -l)
  n_lines_per_event=$((10000/n_events_10k))
fi

# output
echo "$file,$ext,$nevents,$n_lines_per_event" | tee -a "${out}"
