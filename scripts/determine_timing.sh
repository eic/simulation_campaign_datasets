#!/bin/bash

nlines=1000
while IFS="," read file nevents ; do
  cifile=${file/EVGEN/EVGEN\/CI}
  cidir=$(dirname ${cifile})
  mkdir -p ${cidir}
  mc head -n $nlines S3/eictest/ATHENA/$file > ${cifile}
  n=$(grep ^E ${cifile} | wc -l)
  test $n -gt 0 || exit -1
  t1=$(date +%s.%N)
  /opt/campaigns/hepmc3/scripts/run.sh ${cifile} $((nevents-1))
  t2=$(date +%s.%N)
  dt=$(python -c "print(1000.0*($t2-$t1)/($n))")
  echo "$file,$nevents,$dt"
done
