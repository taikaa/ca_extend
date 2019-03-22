#!/bin/bash

source "$PT__installdir/ca_regen/files/common.sh"

echo "test" | base64 -w 0 - &>/dev/null || fail "base64_test" "This utility requires a version of base64 with the -w flag"

new_cert="$(bash "$PT__installdir/ca_regen/files/regen.sh" 2>"$_tmp")" || fail "regen_cert"
contents="$(base64 -w 0 $new_cert 2>$_tmp)" || fail "encode_cert"

success "{ \"status\": \"success\", \"new_cert\": \"$new_cert\", \"contents\": \"$contents\" }"
