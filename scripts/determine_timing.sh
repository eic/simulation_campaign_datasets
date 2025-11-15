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

n=$n_events_test
if [[ $ext != "hepmc3.tree.root" && $ext != "steer" ]]; then
  echo "Error: Input extension is not recognized. Only 'hepmc3.tree.root' or 'steer' format is accepted. Please see the input pre-processing policy https://eic.github.io/epic-prod/documentation/input_preprocessing.html"
  exit -1
fi

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

logfile=${RESULTS_BASE:-results}/logs/${file}.out
mkdir -p $(dirname ${logfile})

echo "INFO [determine_timing.sh] - DETECTOR_CONFIG = ${DETECTOR_CONFIG:-epic_craterlake}"
echo "INFO [determine_timing.sh] - DETECTOR_VERSION = ${DETECTOR_VERSION:-main}"
echo "INFO [determine_timing.sh] - EBEAM = ${EBEAM:-18}"
echo "INFO [determine_timing.sh] - PBEAM = ${PBEAM:-275}"
echo "INFO [determine_timing.sh] - NEVENTS_PER_TEST = ${n_events_test}"
echo "INFO [determine_timing.sh] - RESULTS_BASE = ${RESULTS_BASE:-results}"

# time for 1 event (first)
t1=$(date +%s.%N)
/opt/campaigns/hepmc3/scripts/run.sh EVGEN/${file} ${ext} 1 2>&1 | tee ${logfile}.1
t2=$(date +%s.%N)
dt01=$(echo "scale=5; ($t2-$t1)" | bc -l)
duf01=$(du -sc $TMPDIR/*/FULL | tail -n 1 | awk '{print($1)}')
dur01=$(du -sc $TMPDIR/*/RECO | tail -n 1 | awk '{print($1)}')

# time for n events (last, so will overwrite 1 event)
t1=$(date +%s.%N)
/opt/campaigns/hepmc3/scripts/run.sh EVGEN/${file} ${ext} ${n} 2>&1 | tee ${logfile}.n
t2=$(date +%s.%N)
dt0n=$(echo "scale=5; ($t2-$t1)" | bc -l)
duf0n=$(du -sc $TMPDIR/*/FULL | tail -n 1 | awk '{print($1)}')
dur0n=$(du -sc $TMPDIR/*/RECO | tail -n 1 | awk '{print($1)}')

# initialization correction (require at least a minimum positive difference)
dt1=$(echo "scale=5; if($dt0n-$dt01>0.1*$dt01) print(($dt0n-$dt01)/($n-1)) else print(0.1*$dt01/$n)" | bc -l)
dt0=$(echo "scale=5; if($dt01>$dt1) print(($dt01-$dt1)) else print(100)" | bc -l)

# initialization correction (require at least a minimum positive difference)
# full data usage
duf1=$(echo "scale=5; if($duf0n-$duf01>0.1*$duf01) print(($duf0n-$duf01)/($n-1)) else print(0.1*$duf01/$n)" | bc -l)
duf0=$(echo "scale=5; if($duf01>$duf1) print(($duf01-$duf1)) else print(100)" | bc -l)
# reco data usage
dur1=$(echo "scale=5; if($dur0n-$dur01>0.1*$dur01) print(($dur0n-$dur01)/($n-1)) else print(0.1*$dur01/$n)" | bc -l)
dur0=$(echo "scale=5; if($dur01>$dur1) print(($dur01-$dur1)) else print(100)" | bc -l)

# output
echo "$file,$ext,$nevents,$dt0,$dt1,$duf0,$duf1,$dur0,$dur1" | tee -a "${out}"
