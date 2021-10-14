#!/bin/bash

file=${1?Specify filename}
nevents=${2?Specify nevents}

# number of hepmc lines to read
nlines=1000

# ensure CI is added to local file
cifile=${file/EVGEN/EVGEN\/CI}
cidir=$(dirname ${cifile})
mkdir -p ${cidir}

# get extension
type=${file##*.}
if [ "${type}" == "hepmc" ] ; then
  # get first lines of hepmc file
  mc head -n $nlines S3/eictest/ATHENA/${file} > ${cifile}
  test -f ${cifile}
  # count events
  n=$(grep ^E ${cifile} | wc -l)
  n=$((n-1)) # last event is corrupted
  test $n -gt 0 || exit -1
  type="hepmc3"
elif [ "${type}" == "steer" ] ; then
  # get full steer file
  mc cp -q S3/eictest/ATHENA/${file} ${cifile} > /dev/null
  test -f ${cifile}
  # use 10 lines per event equivalent
  n=$((nlines/10))
  type="single"
else
  echo "Error: extension not recognized"
  exit -1
fi

logfile=results/logs/${cifile}.out
mkdir -p $(dirname ${logfile})

# time for n events
t1=$(date +%s.%N)
/opt/campaigns/${type}/scripts/run.sh ${cifile} ${n} 2>&1 > ${logfile}.n
t2=$(date +%s.%N)
dt0n=$(echo "scale=5; ($t2-$t1)" | bc -l)

# time for 1 event
t1=$(date +%s.%N)
/opt/campaigns/${type}/scripts/run.sh ${cifile} 1 2>&1 > ${logfile}.1
t2=$(date +%s.%N)
dt01=$(echo "scale=5; ($t2-$t1)" | bc -l)

# initialization correction
dt1=$(echo "scale=5; if($dt0n>$dt01) print(($dt0n-$dt01)/($n-1)) else print($dt0n/$n)" | bc -l)
dt0=$(echo "scale=5; if($dt01>$dt1)  print(($dt01-$dt1))         else print(100)"      | bc -l)

# output
echo "$file,$nevents,$dt0,$dt1"
