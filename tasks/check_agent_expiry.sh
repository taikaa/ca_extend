#!/bin/bash

declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/ca_extend/files/common.sh"
PUPPET_BIN='/opt/puppetlabs/puppet/bin'

valid=()
expired=()

to_date="${date:-+3 months}"
to_date="$(date --date="$to_date" +"%s")" || fail "Error calculating date"

# It's possible that we are not on a Puppet AIO system. If we cannot find a
# openssl binary in the AIO directory, we accept one in $PATH
if [ "$(command -v "${PUPPET_BIN}/openssl")" ]; then
  openssl="${PUPPET_BIN}/openssl"
else
  openssl="$(command -v openssl)"
fi

shopt -s nullglob

for f in "$($PUPPET_BIN/puppet config print signeddir)"/*; do
  # The -checkend command in openssl takes a number of seconds as an argument
  # However, on older versions we may overflow a 32 bit integer if we use that
  # So, we'll use bash arithmetic and `date` to do the comparison
  expiry_date="$(${openssl} x509 -enddate -noout -in "${f}")"
  expiry_date="${expiry_date#*=}"
  expiry_seconds="$(date --date="$expiry_date" +"%s")" || fail "Error calculating expiry date from enddate"

  if (( to_date >= expiry_seconds )); then
    expired+=("\"$f\"")
  else
    valid+=("\"$f\"")
  fi
done

# This is ugly, we as of now we don't include jq binaries in Bolt
# As long as there aren't weird characters in certnames it should be ok
(IFS=,; printf '{"valid": [%s], "expiring": [%s]}' "${valid[*]}" "${expired[*]}")
