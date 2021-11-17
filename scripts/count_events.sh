#!/bin/bash

file=${1?Specify filename}
nevents=${2:-} # allow empty
n_lines_per_event=${3:-} # allow empty

if [ -z "$(mc ls S3rw/eictest/ATHENA/${file}.gz)" ] ; then
  # regular
  GUNZIP=(cat)
else
  # gzipped
  GUNZIP=(gunzip -c)
fi

# if nevents not known
if [ -z "${nevents}" ] ; then
  # count events
  nevents=$(mc cat S3/eictest/ATHENA/${file} | ${GUNZIP[@]} | grep ^E | wc -l)
fi

# if n_lines_per_event not known
if [ -z "${n_lines_per_event}" ] ; then
  # count events in 10k lines
  n_events_10k=$(mc cat S3/eictest/ATHENA/${file} | ${GUNZIP[@]} | head -n 10000 | grep ^E | wc -l)
  n_lines_per_event=$((10000/n_events_10k))
fi

# output
echo "$file,$nevents,$n_lines_per_event"
