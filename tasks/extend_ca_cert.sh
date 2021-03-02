#!/bin/bash

declare PT__installdir
# shellcheck disable=SC1090
source "$PT__installdir/ca_extend/files/common.sh"

echo "test" | base64 -w 0 - &>/dev/null || fail "This script requires a version of base64 with the -w flag"

new_cert="$(bash "$PT__installdir/ca_extend/files/extend.sh")" || fail "Error extending CA certificate expiry date"
contents="$(base64 -w 0 "$new_cert")" || fail "Error encoding CA certificate"

success "{ \"status\": \"success\", \"new_cert\": \"$new_cert\", \"contents\": \"$contents\" }"
