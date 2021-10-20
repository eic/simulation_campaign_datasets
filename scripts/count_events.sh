#!/bin/bash

file=${1?Specify filename}
nevents=${2:-} # allow empty
n_lines_per_event=${3:-} # allow empty

# if nevents not known
if [ -z "$nevents" -o -z "${n_lines_per_event}" ] ; then
  # count events
  nevents=$(mc cat S3/eictest/ATHENA/$file | grep ^E | wc -l)
  # count events in 10k lines
  n_events_10k=$(mc head -n 10000 S3/eictest/ATHENA/$file | grep ^E | wc -l)
  n_lines_per_event=$((10000/n_events_10k))
fi

# output
echo "$file,$nevents,$n_lines_per_event"
