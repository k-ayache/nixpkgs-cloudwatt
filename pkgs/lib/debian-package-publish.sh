#!/usr/bin/env bash

set -e
[ -n "${DEBUG}" ] && set -x

aptly="http://aptly.int0.aub.cloudwatt.net/api"
upload_directory=$(uuidgen)

#-------------------------------------------------------------------------------
# add_files_to_repository
#-------------------------------------------------------------------------------
add_files_to_repository() {
  local repository="$1"
  local upload_directory="$2"

  echo "adding files from directory ${upload_directory} to repository ${repository}..."
  local code=$(http_post repos/${repository}/file/${upload_directory})
  [ "${code}" -eq 200 ] && return

  error "got http code ${code} when adding files to repository ${repository}"
}

#-------------------------------------------------------------------------------
# create_repository
#-------------------------------------------------------------------------------
create_repository() {
  local repository="$1"

  local code=$(http_get repos/${repository})
  [ "${code}" -eq 200 ] && {
    echo "not creating repository ${repository} as it already exists"
    return
  }

  local data=$(printf '{"Name": "%s"}' ${repository})
  echo "creating repository ${repository}..."
  code=$(http_post repos "${data}")
  [ "${code}" -eq 201 ] && return

  error "got http code ${code} when creating repository ${repository}"
}

#-------------------------------------------------------------------------------
# error
#-------------------------------------------------------------------------------
error() {
  echo "error: $1"
  exit 2
}

#-------------------------------------------------------------------------------
# http_get
#-------------------------------------------------------------------------------
http_get() {
  local path="$1"

  curl -sL -w "%{http_code}" -o /dev/null \
    -X GET ${aptly}/${path}
}

#-------------------------------------------------------------------------------
# http_post
#-------------------------------------------------------------------------------
http_post() {
  local path="$1"
  local data="$2"

  curl -sL -w "%{http_code}" -o /dev/null \
    -X POST -H "Content-Type: application/json" \
    --data "${data}" ${aptly}/${path}
}

#-------------------------------------------------------------------------------
# http_put
#-------------------------------------------------------------------------------
http_put() {
  local path="$1"
  local data="$2"

  curl -sL -w "%{http_code}" -o /dev/null \
    -X PUT -H "Content-Type: application/json" \
    --data "${data}" ${aptly}/${path}
}

#-------------------------------------------------------------------------------
# publish_repository
#-------------------------------------------------------------------------------
publish_repository() {
  local repository="$1"
  local distribution="$2"

  local data=$(printf '{"Distribution": "%s"' ${distribution})
  data=$(printf '%s, "Sources": [{"Name": "%s"}]' "${data}" ${repository})
  data=$(printf '%s, "Architectures": ["amd64"]' "${data}")
  data=$(printf '%s, "SourceKind": "local"}"' "${data}")

  echo "publishing repositry ${repository} for distribution ${distribution}..."
  local code=$(http_post publish/${repository} "${data}")
  [ "${code}" -eq 201 ] && return

  [ "${code}" -eq 400 ] && {
    local data='{"ForceOverwrite": true}'
    echo "forcing re-publishing of repository ${repository} for ditribution ${distribution}..."
    code=$(http_put publish/${repository}/${distribution} "${data}")
    [ "${code}" -eq 200 ] && return
  }

  error "got http code ${code} when publishing repository ${repository}"
}

#-------------------------------------------------------------------------------
# upload_files
#-------------------------------------------------------------------------------
upload_files() {
  local upload_directory="$1"
  shift

  files=0
  for directory in "$@"; do
    for file in ${directory}/*.deb; do
      echo "uploading file ${file} to directory ${upload_directory}..."
      [ -f ${file} ] && {
        curl -sL -F "file=@${file}" ${aptly}/files/${upload_directory}
        files=$((files + 1))
      }
    done
  done
  echo "uploaded ${files} files"
}

#-------------------------------------------------------------------------------
# usage
#-------------------------------------------------------------------------------
usage() {
  cat << EOF
Usage: package-publish -d distribution -r repository [<DIRECTORY>...]

Parameters:
  -d=distribution  Distribution codename (precise, trusty or xenial)
  -h               This help message
  -r=repository    Repository name
EOF
  exit ${1}
}

#-------------------------------------------------------------------------------
# main
#-------------------------------------------------------------------------------
while getopts "d:hr:" option; do
  case ${option} in
    d)
      distribution=${OPTARG}
      ;;
    h)
      usage 0
      ;;
    r)
      repository=${OPTARG}
      ;;
    *)
      echo "Unknown option: ${option}"
      usage 1
      ;;
  esac
done
shift $((OPTIND - 1))

[ -z "${distribution}" -o -z "${repository}" ] && usage 1

directories="$@"
[ -z "${directories}" ] && directories="/var/lib/packages"

create_repository ${repository}
upload_files ${upload_directory} ${directories}
add_files_to_repository ${repository} ${upload_directory}
publish_repository ${repository} ${distribution}
