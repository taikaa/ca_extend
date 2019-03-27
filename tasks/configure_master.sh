#!/bin/bash

source "$PT__installdir/ca_regen/files/common.sh"

\cp -R /etc/puppetlabs/puppet/ssl /var/puppetlabs/backups 2>"$_tmp" || fail "backup_ssl"

\cp "$new_cert" /etc/puppetlabs/puppet/ssl/ca/ca_crt.pem 2>"$_tmp" || fail "move_cert"
\cp "$new_cert" /etc/puppetlabs/puppet/ssl/certs/ca.pem 2>"$_tmp" || fail "move_cert"

PATH="${PATH}:/opt/puppetlabs/bin" puppet infrastructure configure --no-recover 2>"$_tmp" || fail "infra_configure"

success '{ "status": "success" }'
