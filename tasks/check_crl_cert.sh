#!/bin/bash

declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/ca_extend/files/common.sh"
PUPPET_BIN='/opt/puppetlabs/puppet/bin'

hostcert="$($PUPPET_BIN/puppet config print cacrl)"
[[ -e $hostcert ]] || fail "ERROR: primary server CA cert is not found."

expiry_date="$($PUPPET_BIN/openssl crl -nextupdate -noout -in "$hostcert")"
expiry_date="${expiry_date#*=}"
expiry_seconds="$(date --date="$expiry_date" +"%s")" || fail "Error calculating expiry date from nextupdate"

if (( $(date +"%s") >= expiry_seconds )); then
  success '{ "status": "expired", "message": "Ca crl cert is expired, run the crl_truncate task to generate a new crl" }'
else
  success '{ "status": "success", "message": "Ca crl cert is ok" }'
fi
