#!/bin/bash

file=${1?Specify filename}
nevents=${2:-} # allow empty
n_lines_per_event=${3:-} # allow empty

if [ -z "$(mc ls S3rw/eictest/ATHENA/${file}.gz)" ] ; then
  echo "gzip $file"
  mc ls S3rw/eictest/ATHENA/${file}
  mc cat S3rw/eictest/ATHENA/${file} | gzip -c | mc pipe S3rw/eictest/ATHENA/${file}.gz
  mc ls S3rw/eictest/ATHENA/${file}.gz
fi
