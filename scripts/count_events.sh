#!/bin/bash

while IFS="," read file nevents ; do
  if [ -z "$nevents" ] ; then
    nevents=$(mc cat S3/eictest/ATHENA/$file | grep ^E | wc -l)
  fi
  mkdir -p results
  echo "$file,$nevents"
done
