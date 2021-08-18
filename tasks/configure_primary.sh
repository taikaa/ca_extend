#!/bin/bash

declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/ca_extend/files/common.sh"

PUPPET_BIN='/opt/puppetlabs/puppet/bin'
ssldir="$($PUPPET_BIN/puppet config print ssldir)"
cadir="$($PUPPET_BIN/puppet config print cadir)"
ca_dirs=("$ssldir" "$cadir")

mkdir -p /var/puppetlabs/backups/
cp -aR "$ssldir" /var/puppetlabs/backups || fail "Error backing up '/etc/puppetlabs/puppet/ssl'"

# shellcheck disable=SC2154
[[ $regen_primary_cert == "true" ]] && {
  # add the command substitutions to get ssldir and cadir to an array
  find "${ca_dirs[@]}" -name "$($PUPPET_BIN/puppet config print certname).pem" -delete
}

# shellcheck disable=SC2154
cp "$new_cert" "${cadir}/ca_crt.pem" || fail "Error copying 'ca_crt.pem'"
cp "$new_cert" "${ssldir}/certs/ca.pem" || fail "Error copying 'ca.pem'"

PATH="${PATH}:/opt/puppetlabs/bin" puppet infrastructure configure --no-recover || fail "Error running 'puppet infrastructure configure'"

success '{ "status": "success" }'
