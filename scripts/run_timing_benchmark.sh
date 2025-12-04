#!/bin/bash

# Wrapper script to run timing benchmark for a specific dataset locally
# Usage: ./run_timing_benchmark.sh <path-to-dataset.csv>

set -e

# Determine script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -eq 0 ]; then
    echo "ERROR: No dataset CSV file provided"
    echo "Usage: $0 <path-to-dataset.csv>"
    echo ""
    echo "Examples:"
    echo "  $0 SIDIS/DIJET/pythia6.428-dijet-v1.0_PGF_noRC_ep_18x275_q2_1to20000_ab.csv"
    echo "  $0 EXCLUSIVE/UPSILON.csv"
    exit 1
fi

DATA="$1"

# Change to repo root directory
cd "$REPO_ROOT"

if [ ! -f "$DATA" ]; then
    echo "ERROR: File '$DATA' not found"
    exit 1
fi

# Set default environment variables (can be overridden)
export DETECTOR_CONFIG="${DETECTOR_CONFIG:-epic_craterlake}"
export DETECTOR_VERSION="${DETECTOR_VERSION:-main}"
export EBEAM="${EBEAM:-18}"
export PBEAM="${PBEAM:-275}"
export NEVENTS_PER_TEST="${NEVENTS_PER_TEST:-100}"
export IMAGE_TAG="${IMAGE_TAG:-nightly}"
export RESULTS_BASE="results/${IMAGE_TAG}/${DETECTOR_CONFIG}/${DETECTOR_VERSION}"

# Set up parallel alias
shopt -s expand_aliases
alias parallel='parallel -k --lb -j 1 --colsep ","'

echo "========================================"
echo "Running timing benchmark for: $DATA"
echo "========================================"
echo "DETECTOR_CONFIG = ${DETECTOR_CONFIG}"
echo "DETECTOR_VERSION = ${DETECTOR_VERSION}"
echo "EBEAM = ${EBEAM}"
echo "PBEAM = ${PBEAM}"
echo "NEVENTS_PER_TEST = ${NEVENTS_PER_TEST}"
echo "IMAGE_TAG = ${IMAGE_TAG}"
echo "RESULTS_BASE = ${RESULTS_BASE}"
echo "========================================"
echo ""

# Stage 1: Glob - Find matching files
echo "[1/3] Running glob stage to find matching files..."
mkdir -p $(dirname ${RESULTS_BASE}/datasets/glob/$DATA)
grep -v "^\#" $DATA | parallel scripts/glob.sh ${RESULTS_BASE}/datasets/glob/$DATA {}
sort -o ${RESULTS_BASE}/datasets/glob/$DATA ${RESULTS_BASE}/datasets/glob/$DATA
echo "✓ Glob stage complete"
echo ""

# Stage 2: Nevents - Count events
echo "[2/3] Running nevents stage to count events..."
mkdir -p $(dirname ${RESULTS_BASE}/datasets/nevents/$DATA)
grep -v "^\#" ${RESULTS_BASE}/datasets/glob/$DATA | parallel scripts/count_events.sh ${RESULTS_BASE}/datasets/nevents/$DATA {}
sort -o ${RESULTS_BASE}/datasets/nevents/$DATA ${RESULTS_BASE}/datasets/nevents/$DATA
echo "✓ Nevents stage complete"
echo ""

# Stage 3: Timings - Run timing benchmarks
echo "[3/3] Running timings stage (this may take a while)..."
mkdir -p $(dirname ${RESULTS_BASE}/datasets/timings/$DATA)
# First file with timing measurement
grep -v "^\#" ${RESULTS_BASE}/datasets/nevents/$DATA | sed '1!d' | parallel scripts/determine_timing.sh ${RESULTS_BASE}/datasets/timings/$DATA {}
# Remaining files using timing from first file
IFS="," read file ext nevents dt0 dt1 < ${RESULTS_BASE}/datasets/timings/$DATA
export dt0 dt1
grep -v "^\#" ${RESULTS_BASE}/datasets/nevents/$DATA | sed '1d' | parallel scripts/determine_timing.sh ${RESULTS_BASE}/datasets/timings/$DATA {}
sort -o ${RESULTS_BASE}/datasets/timings/$DATA ${RESULTS_BASE}/datasets/timings/$DATA
echo "✓ Timings stage complete"
echo ""

# Show results
echo "========================================"
echo "RESULTS"
echo "========================================"
echo ""
echo "Timing results saved to:"
echo "  ${RESULTS_BASE}/datasets/timings/$DATA"
echo ""
echo "Summary:"
cat ${RESULTS_BASE}/datasets/timings/$DATA | awk 'BEGIN {FS=","} {sum+=$3*$5+$4} END {printf("  Total core-hours: %.2f\n",sum/3600)}'
cat ${RESULTS_BASE}/datasets/timings/$DATA | awk 'BEGIN {FS=","} {sum+=$3*$7+$6} END {printf("  Total size (full): %.2f GB\n",sum/1048576)}'
cat ${RESULTS_BASE}/datasets/timings/$DATA | awk 'BEGIN {FS=","} {sum+=$3*$9+$8} END {printf("  Total size (reco): %.2f GB\n",sum/1048576)}'
echo ""
echo "Full timing data:"
cat ${RESULTS_BASE}/datasets/timings/$DATA
