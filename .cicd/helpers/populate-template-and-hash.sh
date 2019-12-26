#!/bin/bash
set -eo pipefail

ONLYHASH=false
DEBUG=false
DOCKERIZATION=${DOCKERIZATION:-true}

function usage() {
  printf "Usage: \\n
  %s [ -h : Only return the hash, don't create the file ] (PATTERN_ONE) (PATTERN_TWO) \\n
  - PATTERN_ONE and _TWO default to three backticks -> \`\`\`
  [ Examples ] \\n
    $ %s -d
        - Considered Debug only; Prints out the entire final version of the file with all of the blocks it parsed
    $ %s
        - Generates /tmp/\${IMAGE_TAG/FILE_NAME} file using the documentation's code blocks (all of them)
        - Populates DETERMINED_HASH and FULL_TAG variables using the file's contents
    $ %s -h
        - Doesn't generate a /tmp/\${IMAGE_TAG/FILE_NAME} file
        - Populates DETERMINED_HASH and FULL_TAG variables using the file's contents
    $ %s '<!-- DAC BUILD -->' '<!-- INSTALL END'
        - Generates /tmp/\${IMAGE_TAG/FILE_NAME} file using the code blocks from the first <!-- DAC BUILD --> all the way to the <!-- DAC INSTALL END -->
        - Populates DETERMINED_HASH and FULL_TAG variables using the file's contents
    \\n\\n" "$0" "$0" "$0" "$0" 1>&2
   exit 1
}

if [ $# -ne 0 ]; then
  while getopts "hd?" opt; do
    case "${opt}" in
        h)
          ONLYHASH=true
        ;;
        d)
          DEBUG=true
          [[ "$(uname)" == 'Darwin' ]] && DOCKERIZATION=false
        ;;
        ? )
          usage
        ;;
        : )
          echo "Invalid option: $OPTARG requires an argument" 1>&2
        ;;
        * )
          usage
        ;;
    esac
  done
  shift $((OPTIND -1))
fi

# If we're running this script a second time (with ONLYHASH), set a tmpfile name
[[ ${POPULATED_FILE_NAME:-false} == false ]] && export POPULATED_FILE_NAME=${FILE_NAME:-$IMAGE_TAG} || POPULATED_FILE_NAME="tmpfile"
# Collect commands from code block, add RUN before the start of commands, and add it to temporary template
if [[ ! -z $@ ]]; then
  POP_COMMANDS=""
  for PATTERN in "$@"; do
    POP_COMMANDS="$POP_COMMANDS
$(cat .cicd/docs/${IMAGE_TAG:-$FILE_NAME}.md | sed -n "/$PATTERN/,/END -->/p")"
    POP_COMMANDS=$(echo "$POP_COMMANDS" | sed '/<!-- DAC IGNORE/,/<!-- DAC IGNORE/d') # Remove test block (we run ctest in ci/cd)
    POP_COMMANDS=$(echo "$POP_COMMANDS" | grep -v -e "$PATTERN" -e '<!--' -e '-->' -e '```' -e '\#.*' -e '^$') # Sanitize
  done
  POP_COMMANDS=$(echo "$POP_COMMANDS" | grep -v -e '^$') 
else
  PATTERN='<!-- DAC'
  POP_COMMANDS=$(cat .cicd/docs/${IMAGE_TAG:-$FILE_NAME}.md | sed -n "/$PATTERN/,/END -->/p")
  POP_COMMANDS=$(echo "$POP_COMMANDS" | sed '/<!-- DAC IGNORE/,/<!-- DAC IGNORE/d') # Remove test block (we run ctest in ci/cd)
  POP_COMMANDS=$(echo "$POP_COMMANDS" | grep -v -e "$PATTERN" -e '<!--' -e '-->' -e '```' -e '\#.*' -e '^$') # Sanitize
fi
if [[ ! ${IMAGE_TAG:-$FILE_NAME} =~ 'macos' ]]; then # Linux / Docker
  ( [[ $DOCKERIZATION == true ]] || [[ $ONLYHASH == true ]] ) && POP_COMMANDS=$(echo "$POP_COMMANDS" | awk '{ \
  if ( $0 ~ /^[ ].*/ ) { print $0 } \
  else if ( $0 ~ /^export.*=([^\s]+).*$/ ) { gsub(/export /,"",$0); print "ENV " $0 } \
  else { print "RUN " $0 } }')
  export FILE_EXTENSION=".dockerfile"
  export APPEND_LINE=3
else # Mac OSX
  export FILE_EXTENSION=".sh"
  export APPEND_LINE=4
fi

echo "$POP_COMMANDS" > /tmp/commands
if ( [[ $DOCKERIZATION == false ]] && [[ $ONLYHASH == false ]] ); then
  if [[ "$(uname)" == 'Darwin' ]]; then # Mac needs to use the template fr envs
    cat .cicd/platform-templates/${FILE:-"${IMAGE_TAG}$FILE_EXTENSION"} > /tmp/$POPULATED_FILE_NAME
    # Remove anything below "# Anything below here is exclusive to our CI/CD"
    sed -i -e '/Anything below here is exclusive to our CI\/CD/,$d' /tmp/$POPULATED_FILE_NAME
    echo "$POP_COMMANDS" >> /tmp/$POPULATED_FILE_NAME
  else
    echo "$POP_COMMANDS" > /tmp/$POPULATED_FILE_NAME
  fi
else
  awk "NR==$APPEND_LINE{print;system(\"cat /tmp/commands\");next} 1" .cicd/platform-templates/${FILE:-"${IMAGE_TAG}$FILE_EXTENSION"} > /tmp/$POPULATED_FILE_NAME
fi
export DETERMINED_HASH=$(sha1sum /tmp/$POPULATED_FILE_NAME | awk '{ print $1 }')
export HASHED_IMAGE_TAG="eos-$(basename ${FILE_NAME:-$IMAGE_TAG} | awk '{split($0,a,/\.(d|s)/); print a[1] }')-${DETERMINED_HASH}"
export FULL_TAG="eosio/ci:$HASHED_IMAGE_TAG"
if [[ $TRAVIS == true ]]; then
  sed -i -e 's/^HOME=\/Users\/anka/HOME=\/Users\/travis/g' /tmp/$POPULATED_FILE_NAME
  COMMIT_ID=$TRAVIS_COMMIT
else
  COMMIT_ID=$BUILDKITE_COMMIT
fi
sed -i -e 's/&& brew install git/&& brew install git || true/g' /tmp/$POPULATED_FILE_NAME
sed -i -e "s/eos.git \$EOS_LOCATION/eos.git \$EOS_LOCATION \&\& cd \$EOS_LOCATION \&\& git pull \&\& git checkout -f $COMMIT_ID/g" /tmp/$POPULATED_FILE_NAME # MUST BE AFTER WE GENERATE THE HASH
chmod +x /tmp/$POPULATED_FILE_NAME
[[ $DEBUG == true ]] && cat /tmp/$POPULATED_FILE_NAME
if [[ $ONLYHASH == true ]]; then
  rm -f /tmp/$POPULATED_FILE_NAME && export POPULATED_FILE_NAME=${FILE_NAME:-$IMAGE_TAG}
fi