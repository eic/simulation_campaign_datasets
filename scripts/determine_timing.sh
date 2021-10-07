#!/bin/bash

nlines=1000
while IFS="," read file nevents ; do
  cifile=${file/EVGEN/EVGEN\/CI}
  cidir=$(dirname ${cifile})
  mkdir -p ${cidir}
  type=${file##*.}
  if [ "${type}" == "hepmc" ] ; then
    mc head -n $nlines S3/eictest/ATHENA/$file > ${cifile}
    n=$(grep ^E ${cifile} | wc -l)
    n=$((n-1)) # last event is corrupted
    test $n -gt 0 || exit -1
    type="hepmc3"
  elif [ "${type}" == "steer" ] ; then
    mc cp S3/eictest/ATHENA/${file} ${cifile}
    n=$((nlines/10)) # 10 lines per event equivalent
    type="single"
  else
    echo "Error: extension not recognized"
    exit -1
  fi
  logfile=results/logs/${cifile}.out
  mkdir -p $(dirname ${logfile})
  t1=$(date +%s.%N)
  /opt/campaigns/${type}/scripts/run.sh ${cifile} ${n} 2>&1 > ${logfile}
  t2=$(date +%s.%N)
  dt=$(echo "scale=5; ($t2-$t1)/($n)" | bc -l)
  echo "$file,$nevents,$dt"
done
