#!/bin/bash -e

# Use this script to rebuild the Dockerfiles and all variants for a particular
# release. Before running this, you must first delete the existing release
# directory.
#
# TODO: to conform with other similar setups, this likely needs to become
# "update.sh" and be taught how to derive the latest version (e.g. 1.2.0) from
# a given release (e.g. 1.2) and assemble a .travis.yml file dynamically.
#
# See other repos (e.g. httpd, cassandra) for update.sh examples.


function usage() {
    echo >&2 "usage: $0 -r flink-release -f flink-version"
}

function error() {
    local msg="$1"
    if [ -n "$2" ]; then
        local code="$2"
    else
        local code=1
    fi
    echo >&2 "$msg"
    exit "$code"
}

flink_release= # Like 1.2
flink_version= # Like 1.2.0

while getopts r:f:h arg; do
  case "$arg" in
    r)
      flink_release=$OPTARG
      ;;
    f)
      flink_version=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done

if [ -z "$flink_release" ] || [ -z "$flink_version" ]; then
    usage
    exit 1
fi

if [[ ! "$flink_version" =~ ^$flink_release\.+ ]]; then
    error "Flink release must be prefix of version"
fi

# Defaults, can vary between versions
scala_versions=2.11
java_versions=(1.8-202107081152, 11-202201252233)

if [ -d "$flink_release" ]; then
    error "Directory $flink_release already exists; delete before continuing"
fi

mkdir "$flink_release"

source "$(dirname "$0")"/generator.sh

echo -n >&2 "Generating Dockerfiles..."
for source_variant in "${SOURCE_VARIANTS[@]}"; do
    for scala_version in "${scala_versions[@]}"; do
        for java_version in "${java_versions[@]}"; do
            dir="$flink_release/scala_${scala_version}-java${java_version}-${source_variant}"

            flink_url_file_path=flink/flink-${flink_version}/flink-${flink_version}-bin-scala_${scala_version}.tgz

            flink_tgz_url="https://www.apache.org/dyn/closer.cgi?action=download&filename=${flink_url_file_path}"

            mkdir "$dir"
            generateDockerfile "${dir}" "${flink_tgz_url}" ${java_version} ${source_variant}
            generateReleaseMetadata "${dir}" ${flink_release} ${flink_version} ${scala_version} ${java_version} ${source_variant}
        done
    done
done
echo >&2 " done."
