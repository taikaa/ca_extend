#!/bin/bash

source "$PT__installdir/ca_extend/files/common.sh"

\cp -R /etc/puppetlabs/puppet/ssl /var/puppetlabs/backups || fail "backup_ssl"

\cp "$new_cert" /etc/puppetlabs/puppet/ssl/ca/ca_crt.pem || fail "move_cert"
\cp "$new_cert" /etc/puppetlabs/puppet/ssl/certs/ca.pem || fail "move_cert"

PATH="${PATH}:/opt/puppetlabs/bin" puppet infrastructure configure --no-recover || fail "infra_configure"

success '{ "status": "success" }'
