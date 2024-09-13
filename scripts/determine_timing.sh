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

# ensure CI is added to local file
dir=$(dirname EVGEN/${file}.${ext})
mkdir -p ${dir}

# select type
type="unknown"
if [[ "${ext}" =~ ^hepmc3\.tree\.root$ ]] ; then

  n=$n_events_test
  type="hepmc3"

elif [[ "${ext}" =~ ^steer$ ]] ; then

  n=$n_events_test
  type="single"

else

  echo "Error: Input extension is not recognized. Only '.hepmc3.tree.root' or '.steer' format is accepted. Please see the input pre-processing policy https://eic.github.io/epic-prod/documentation/input_preprocessing.html"
  exit -1
fi

logfile=results/logs/${file}.out
mkdir -p $(dirname ${logfile})

# time for 1 event (first)
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
