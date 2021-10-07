#!/bin/bash

file=${1?Specify filename}
nevents=${2:-} # allow empty

# if nevents not known
if [ -z "$nevents" ] ; then
  # count events
  nevents=$(mc cat S3/eictest/ATHENA/$file | grep ^E | wc -l)
fi

# output
echo "$file,$nevents"
