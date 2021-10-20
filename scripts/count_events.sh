#!/bin/bash

file=${1?Specify filename}
n_events=${2:-} # allow empty

# if nevents not known
if [ -z "$n_events" ] ; then
  # count events
  n_events=$(mc cat S3/eictest/ATHENA/$file | grep ^E | wc -l)
  n_events_10k=$(mc head -n 10000 S3/eictest/ATHENA/$file | grep ^E | wc -l)
  n_lines_per_event=$((10000/n_events_10k))
fi

# output
echo "$file,$n_events,$n_lines_per_event"
