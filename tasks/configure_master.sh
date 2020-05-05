#!/bin/bash

declare PT__installdir
source "$PT__installdir/ca_extend/files/common.sh"

\cp -R /etc/puppetlabs/puppet/ssl /var/puppetlabs/backups || fail "Error backing up '/etc/puppetlabs/puppet/ssl'"

\cp "$new_cert" /etc/puppetlabs/puppet/ssl/ca/ca_crt.pem || fail "Error copying 'ca_crt.pem'"
\cp "$new_cert" /etc/puppetlabs/puppet/ssl/certs/ca.pem || fail "Error copying 'ca.pem"

PATH="${PATH}:/opt/puppetlabs/bin" puppet infrastructure configure --no-recover || fail "Error running 'puppet infrastructure configure'"

success '{ "status": "success" }'
