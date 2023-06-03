#!/bin/bash
set -Eu # no pipefail to allow head to cut pipe
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

out=${1?Specify output}
file=${2?Specify filename}
ext=${3?Specify extension}
nevents=${4?Specify nevents}
n_lines_per_event=${5?Specify n_lines_per_event}
n_events_test=${NEVENTS_PER_TEST:-100}

if [ -n "${dt0:-}" -a -n "${dt1:-}" ] ; then
  # reuse if already determined
  echo "$file,$ext,$nevents,$dt0,$dt1" | tee -a "${out}"
  exit
fi

# number of hepmc lines to read (includes buffer)
nlines=$((2*n_events_test*n_lines_per_event))

# never write to S3 in these jobs
export S3RW_ACCESS_KEY="" S3RW_SECRET_KEY=""

# ensure CI is added to local file
dir=$(dirname EVGEN/${file}.${ext})
mkdir -p ${dir}

# select type
type="unknown"
if [[ "${ext}" =~ ^hepmc[2]?$ || "${ext}" =~ ^hepmc\.gz$ ]] ; then

  if [[ "${ext}" =~ ^hepmc\.gz$ ]] ; then
    GUNZIP=(gunzip -c)
    ext=${ext/.gz/}
  else
    GUNZIP=(cat)
  fi

  # get first lines of hepmc file
  mc cat S3/eictest/EPIC/EVGEN/${file}.${ext}.gz | ${GUNZIP[@]} | head -n ${nlines} > EVGEN/${file}
  test -f ${file}
  # count events
  n=$(grep ^E ${file} | wc -l)
  n=$((n-1)) # last event is corrupted
  test $n -gt 0 || exit -1
  if [[ "${ext}" =~ ^hepmc2$ ]] ; then
    export USEHEPMC3=false
  fi
  type="hepmc3"

elif [[ "${ext}" =~ ^hepmc3\.tree\.root$ ]] ; then

  n=$n_events_test
  type="hepmc3"

elif [[ "${ext}" =~ ^steer$ ]] ; then

  # get full steer file
  mc cp -q S3/eictest/EPIC/EVGEN/${file}.${ext} EVGEN/${file}.${ext} > /dev/null
  test -f EVGEN/${file}.${ext}
  n=$n_events_test
  type="single"

else

  echo "Error: extension not recognized"
  exit -1

fi

logfile=results/logs/${file}.out
mkdir -p $(dirname ${logfile})

# time for 1 event (first, since will write to S3)
t1=$(date +%s.%N)
/opt/campaigns/${type}/scripts/run.sh EVGEN/${file}.${ext} 1 2>&1 | tee ${logfile}.1
t2=$(date +%s.%N)
dt01=$(echo "scale=5; ($t2-$t1)" | bc -l)

# time for n events (last, so will overwrite 1 event)
t1=$(date +%s.%N)
/opt/campaigns/${type}/scripts/run.sh EVGEN/${file}.${ext} ${n} 2>&1 | tee ${logfile}.n
t2=$(date +%s.%N)
dt0n=$(echo "scale=5; ($t2-$t1)" | bc -l)

# initialization correction (require at least a minimum positive difference)
dt1=$(echo "scale=5; if($dt0n-$dt01>0.1*$dt01) print(($dt0n-$dt01)/($n-1)) else print(0.1*$dt01/$n)" | bc -l)
dt0=$(echo "scale=5; if($dt01>$dt1) print(($dt01-$dt1)) else print(100)" | bc -l)

# output
echo "$file,$ext,$nevents,$dt0,$dt1" | tee -a "${out}"
