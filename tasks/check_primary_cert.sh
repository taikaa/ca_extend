#!/bin/bash

declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/ca_extend/files/common.sh"
PUPPET_BIN='/opt/puppetlabs/puppet/bin'

hostcert="$($PUPPET_BIN/puppet config print hostcert)"
[[ -e $hostcert ]] || fail "ERROR: primary server cert not found.  pass regen_primary_cert=true to the plan to regenerate it if needed."

expiry_date="$($PUPPET_BIN/openssl x509 -enddate -noout -in "$hostcert")"
expiry_date="${expiry_date#*=}"
expiry_seconds="$(date --date="$expiry_date" +"%s")" || fail "Error calculating expiry date from enddate"

if (( $(date +"%s") >= expiry_seconds )); then
  fail "ERROR: the primary server certificate has expired.  Please pass regen_primary_cert=true to the plan to regenerate it."
elif (( $(date --date="+3 months" +"%s") >= expiry_seconds )); then
  success '{ "status": "warn", "message": "WARN: Primary cert expiring within 3 months. Either regenerate manually or pass regen_primary_cert=true to the plan to regenerate it." }'
else
  success '{ "status": "success", "message": "Primary cert ok" }'
fi
