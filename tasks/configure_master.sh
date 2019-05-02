#!/bin/bash

declare PT__installdir
source "$PT__installdir/ca_extend/files/common.sh"

\cp -R /etc/puppetlabs/puppet/ssl /var/puppetlabs/backups || fail "Error backing up ssl dir"

\cp "$new_cert" /etc/puppetlabs/puppet/ssl/ca/ca_crt.pem || fail "Error copying cert"
\cp "$new_cert" /etc/puppetlabs/puppet/ssl/certs/ca.pem || fail "Error copying cert"

PATH="${PATH}:/opt/puppetlabs/bin" puppet infrastructure configure --no-recover || fail "Error configuring infrastructure"

success '{ "status": "success" }'
