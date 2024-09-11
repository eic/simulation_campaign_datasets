set -Eu # no pipefail to allow head to cut pipe
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

out=${1?Specify output}
dirfile=${2?Specify filename}
ext=${3?Specify extension}
nevents=${4:-} # allow empty
n_lines_per_event=${5:-} # allow empty

xrdurl="root://dtn-eic.jlab.org"
xrdbase="/work/eic2/EPIC/EVGEN"

# loop over glob expression
dir=$(dirname ${dirfile})
file=$(basename ${dirfile})
echo ${xrdurl}/${xrdbase}/${dir}/${file}.${ext}
file=${file/'*'/'.*'}
file=${file/'?'/'.*'} 
file=${file/'+'/'\+'}
list=$(xrdfs ${xrdurl} ls ${xrdbase}/${dir} | grep .${ext} | sed "s/.${ext}//g" | grep -E ${file})


for xrdfile in ${list} ; do
  
  # output
  echo "${xrdfile/${xrdbase}\//},$ext,$nevents,$n_lines_per_event" | tee -a "${out}"

done
