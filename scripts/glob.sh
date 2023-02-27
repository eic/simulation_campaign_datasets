set -Eu # no pipefail to allow head to cut pipe
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

out=${1?Specify output}
dirfile=${2?Specify filename}
ext=${3?Specify extension}
nevents=${4:-} # allow empty
n_lines_per_event=${5:-} # allow empty

s3prefix="S3/eictest/EPIC/EVGEN"
s3https="s3https://eics3.sdcc.bnl.gov:9000/eictest/EPIC/EVGEN"
xrootd="root://dtn-eic.jlab.org//work/eic2/EPIC/EVGEN"

# loop over glob expression
dir=$(dirname ${dirfile})
file=$(basename ${dirfile})
echo ${s3prefix}/${dir}/${file}.${ext}
for s3file in $(mc find ${s3prefix}/${dir} -name ${file}.${ext}) ; do

  # unparse
  dirfile=${s3file/${s3prefix}\//}
  dir=$(dirname ${dirfile})
  file=$(basename ${dirfile} .${ext})

  # output
  echo "${dir}/${file},$ext,$nevents,$n_lines_per_event" | tee -a "${out}"

done
