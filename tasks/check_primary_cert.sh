#!/bin/bash

declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/ca_extend/files/common.sh"
PUPPET_BIN='/opt/puppetlabs/puppet/bin'

expiry_date="$($PUPPET_BIN/openssl x509 -enddate -noout -in "$($PUPPET_BIN/puppet config print hostcert)")" || {
  fail "Error finding primary server certificate."
}
expiry_date="${expiry_date#*=}"
expiry_seconds="$(date --date="$expiry_date" +"%s")" || fail "Error calculating expiry date from enddate"

if (( $(date +"%s") >= expiry_seconds )); then
  fail "Error: the primary server certificate has expired.  Please pass regen_primary_cert=true to the plan to regenerate it."
fi

success '{ "status": "success", "message": "Primary cert ok" }'
