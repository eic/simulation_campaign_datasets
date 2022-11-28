#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

file=${1?Specify filename}
ext=${2?Specify extension}
nevents=${3:-} # allow empty
n_lines_per_event=${4:-} # allow empty

if [[ "${ext}" =~ ^hepmc$ ]] ; then
  if [ -z "$(mc ls S3rw/eictest/EPIC/EVGEN/${file}.${ext}.gz)" ] ; then
    echo "gzip ${file}.${ext}"
    mc ls S3rw/eictest/EPIC/EVGEN/${file}.${ext}
    mc cat S3rw/eictest/EPIC/EVGEN/${file}.${ext} | gzip -c | mc pipe S3rw/eictest/EPIC/EVGEN/${file}.${ext}.gz
    mc ls S3rw/eictest/EPIC/EVGEN/${file}.${ext}.gz
  else
    echo "${file}.${ext}.gz already exists; change your input file to use the compressed file"
  fi
elif [[ "${ext}" =~ ^hepmc\.gz$ ]] ; then
  echo "${file}.${ext} already compressed"
else
  echo "${file}.${ext} not recognized"
  exit 1
fi
