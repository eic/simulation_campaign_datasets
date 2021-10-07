#!/bin/bash

file=${1?Specify filename}
nevents=${2?Specify nevents}

nlines=1000

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
  mc cp -q S3/eictest/ATHENA/${file} ${cifile} > /dev/null
  test -f ${cifile}
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
dt0n=$(echo "scale=5; ($t2-$t1)" | bc -l)
# initialization correction
t1=$(date +%s.%N)
/opt/campaigns/${type}/scripts/run.sh ${cifile} 1 2>&1 > /dev/null
t2=$(date +%s.%N)
dt01=$(echo "scale=5; ($t2-$t1)" | bc -l)
dt1=$(echo "scale=5; ($dt0n-$dt01)/($n-1)" | bc -l)
dt0=$(echo "scale=5; ($dt01-$dt1)" | bc -l)
echo "$file,$nevents,$dt0,$dt1"
