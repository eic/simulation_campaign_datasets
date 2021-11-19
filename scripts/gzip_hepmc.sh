#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

file=${1?Specify filename}
nevents=${2:-} # allow empty
n_lines_per_event=${3:-} # allow empty

if [[ "${file}" =~ \.hepmc$ ]] ; then
  if [ -z "$(mc ls S3rw/eictest/ATHENA/${file}.gz)" ] ; then
    echo "gzip ${file}"
    mc ls S3rw/eictest/ATHENA/${file}
    mc cat S3rw/eictest/ATHENA/${file} | gzip -c | mc pipe S3rw/eictest/ATHENA/${file}.gz
    mc ls S3rw/eictest/ATHENA/${file}.gz
  else
    echo "${file}.gz already exists; change your input file to use the compressed file"
  fi
elif [[ "${file}" =~ \.hepmc\.gz$ ]] ; then
  echo "${file} already compressed"
else
  echo "${file} not recognized"
  exit 1
fi
