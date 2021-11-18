#!/bin/bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

file=${1?Specify filename}
nevents=${2?Specify nevents}

# break every 10k events
zeroes="0000"
events_per_chunk=1${zeroes}
pattern="/^E .*${zeroes} /"

# handle gzip inputs
if [[ "${file}" =~ gz$ ]] ; then 
  CAT=(zcat)
  GZIP=(gzip)
else
  CAT=(cat)
  GZIP=(cat)
fi

# get header and footer first
header=`${CAT[@]} ${file} | sed -n '/^E/q;p'`
footer="HepMC::Asciiv3-END_EVENT_LISTING"

# determine padding
pad=%0$(echo "scale=0; l(${nevents}/${events_per_chunk})/l(10)+1" | bc -l)d
echo "${nevents} events in chunks of ${events_per_chunk} requires ${pad} padding"

# split
suffix=".csplit."
prefix=${file}${suffix}
echo "Splitting ${file} on pattern ${pattern}"
${CAT[@]} ${file} | csplit --elide-empty-files --quiet --prefix=${prefix} --suffix-format=${pad} - "%^E%" "${pattern}" "{*}"

# add header and footer, compress
echo "Adding headers and footers again (and compressing)"
for chunkfile in ${prefix}* ; do
  chunk=${chunkfile/*${suffix}/}
  output=${file/.hepmc/_${chunk}.hepmc}
  {
    echo "${header}"
    cat ${chunkfile}
    echo "${footer}"
  } | ${GZIP} > ${output}
  echo "${output}"
  rm ${chunkfile}
  # FIXME double footer on last segment is harmless
done
