#!/bin/bash
set -Eu # no pipefail to allow head to cut pipe
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

out=${1?Specify output}
file=${2?Specify filename}
ext=${3?Specify extension}
nevents=${4:-} # allow empty
n_lines_per_event=${5:-} # allow empty

xrootd="root://dtn-eic.jlab.org//volatile/eic/EPIC/EVGEN"

# if hepmc3.tree.root file
if [[ "${ext}" =~ ^hepmc3\.tree.root$ ]] ; then
  # get entries from xrootd
  nevents=$(root -l -b -q ${xrootd}/${file}.${ext} -e 'cout << hepmc3_tree->GetEntries() << endl;' | tail -n1)
  n_lines_per_event=0
elif [[ "${ext}" =~ ^steer$ ]] ; then 
  true
else 
  echo "Error: Input extension is not recognized. Only '.hepmc3.tree.root' or '.steer' format is accepted. Please see the input pre-processing policy https://eic.github.io/epic-prod/documentation/input_preprocessing.html"
  exit -1
fi

# output
echo "$file,$ext,$nevents,$n_lines_per_event" | tee -a "${out}"
