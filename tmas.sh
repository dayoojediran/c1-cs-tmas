#!/bin/sh

# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Initialize our own variables:
endpoint=""
verbose=0
evaluate=0
evaluationEndpoint=""
region=""
threshold="high"

while getopts "e:E:vr:t:" opt; do
  case "$opt" in
    e)
      echo endpoint set $OPTARG
      endpoint=$OPTARG
      ;;
    E)
      evaluate=1
      evaluationEndpoint=$OPTARG
      ;;
    v)
      verbose=1
      ;;
    r)
      region=$OPTARG
      ;;
    t)
      threshold=$OPTARG
      ;;
  esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

FLAGS=""
[ ! -z "${endpoint}" ] && FLAGS="${FLAGS} --endpoint ${endpoint}"
[ ! -z "${evaluationEndpoint}" ] && FLAGS="${FLAGS} --evaluate --evaluationEndpoint ${evaluationEndpoint}"
[ "${verbose}" -ne 0 ] && FLAGS="${FLAGS} -v"
[ ! -z "${region}" ] && FLAGS="${FLAGS} --region ${region}"

echo Scanning $1
echo Vulnerability threshold: $threshold
# echo "endpoint=$endpoint, verbose=$verbose, evaluate=$evaluate, evaluationEndpoint=$evaluationEndpoint, region=$region, threshold=$threshold, Leftovers: $@"

# Scan
/app/tmas scan $1 ${FLAGS} | tee result.json

fail=0
[ "${threshold}" = "any" ] && \
  [ $(jq '.totalVulnCount' result.json) -ne 0 ] && fail=1

[ "${threshold}" = "critical" ] && \
  [ $(jq '.criticalCount' result.json) -ne 0 ] && fail=2

[ "${threshold}" = "high" ] && \
  [ $(jq '.highCount + .criticalCount' result.json) -ne 0 ] && fail=3

[ "${threshold}" = "medium" ] && \
  [ $(jq '.mediumCount + .highCount + .criticalCount' result.json) -ne 0 ] && fail=4

[ "${threshold}" = "low" ] &&
  [ $(jq '.lowCount + .mediumCount + .highCount + .criticalCount' result.json) -ne 0 ] && fail=5

[ $fail -ne 0 ] && echo Vulnerability threshold exceeded; exit 1
