#!/bin/bash

# For compatibility wither older versions of tasks, we just shove everything in this file
# PT_ variables can be referenced but not assigned 
# shellcheck disable=SC2154
# Exit with an error message and error code, defaulting to 1
fail() {
  # Print a stderr: entry if there were anything printed to stderr
  if [[ -s $_tmp ]]; then
    # Hack to try and output valid json by replacing newlines with spaces.
    echo "{ \"status\": \"error\", \"message\": \"$1\", \"stderr\": \"$(tr '\n' ' ' <"$_tmp")\" }"
  else
    echo "{ \"status\": \"error\", \"message\": \"$1\" }"
  fi

  exit "${2:-1}"
}

success() {
  echo "$1"
  exit 0
}

_tmp="$(mktemp)"
exec 2>>"$_tmp"

# Use indirection to munge PT_ environment variables
# e.g. "$PT_version" becomes "$version"
for v in ${!PT_*}; do
  declare "${v#*PT_}"="${!v}"
done

trap fail ERR

(( EUID == 0 )) || fail 'This script must be run as root'

cat >/tmp/openssl.cnf <<EOF
####################################################################
[ ca ]
default_ca      = CA_default            # The default ca section

####################################################################
[ CA_default ]

dir             = /tmp          # Where everything is kept
certs           = \$dir/certs            # Where the issued certs are kept
crl_dir         = \$dir          # Where the issued crl are kept
database        = \$dir/index.txt        # database index file.
#unique_subject = no                    # Set to 'no' to allow creation of
                                        # several certs with same subject.
new_certs_dir   = \$dir/newcerts         # default place for new certs.

certificate     = /etc/puppetlabs/puppet/ssl/certs/ca.pem       # The CA certificate
serial          = /etc/puppetlabs/puppet/ssl/ca/serial          # The current serial number
crlnumber       = \$dir/crlnumber        # the current crl number
crl             = /etc/puppetlabs/puppet/ssl/certs/ca/ca_crl.pem                # The current CRL
private_key     = /etc/puppetlabs/puppet/ssl/ca/ca_key.pem # The private key

x509_extensions = usr_cert              # The extensions to add to the cert

# Comment out the following two lines for the "traditional"
# (and highly broken) format.
name_opt        = ca_default            # Subject Name options
cert_opt        = ca_default            # Certificate field options

# Extension copying option: use with caution.
# copy_extensions = copy

# Extensions to add to a CRL. Note: Netscape communicator chokes on V2 CRLs
# so this is commented out by default to leave a V1 CRL.
# crlnumber must also be commented out to leave a V1 CRL.
crl_extensions  = crl_ext

default_days     = 365                   # how long to certify for
default_crl_days = $crl_expiration_days  # how long before next CRL
default_md       = default               # use public key default MD
preserve         = no                    # keep passed DN ordering

# A few difference way of specifying how similar the request should look
# For type CA, the listed attributes must be the same, and the optional
# and supplied fields are just that :-)
policy          = policy_match

[ crl_ext ]
# CRL extensions.
# Only issuerAltName and authorityKeyIdentifier make any sense in a CRL.

# issuerAltName=issuer:copy
authorityKeyIdentifier=keyid:always
EOF

cert_num=0
certs=()
PUPPET_BIN='/opt/puppetlabs/puppet/bin'
ssldir="${ssldir:-/etc/puppetlabs/puppet/ssl}"

# Create temp files for each crl in the chain to determine the root
while IFS= read -r line; do
   if [[ $line =~ BEGIN\ X509\ CRL ]]; then
     # Don't trigger the error trap when incrementing returns 1
      (( cert_num++ )) || true
      # This will result in an undefined element 0 in the array, but should be fine
      certs[cert_num]="$(mktemp)"
   fi

   printf '%s\n' "$line" >>"${certs[cert_num]}"
done <"$ssldir"/ca/ca_crl.pem

for cert in "${certs[@]}"; do
   issuer="$("$PUPPET_BIN"/openssl crl -issuer -noout -in "$cert")"
   [[ $issuer =~ Puppet\ Root\ CA ]] && root_crl="$cert"
done

# Assume that a single length crl chain is the root.
# This was the default prior to PE 2019
if (( cert_num == 1 )); then
  root_crl="${certs[cert_num]}"
elif ! [[ $root_crl ]]; then
  printf '%s\n' 'Puppet root CA not found' >"$_tmp"
  fail
fi

# Create an empty index
:>/tmp/index.txt

# openssl requires that the crlnumber be hex with an even number of digits
# %02 in the format string with pad it to two characters, otherwise we have to check for evenness and add a 0 if needed
crl_number="$("$PUPPET_BIN"/openssl crl -crlnumber -noout -in "$ssldir"/ca/ca_crl.pem)"
# Strip everything before the '=' character and increment by one, as the docs say this should be the next crl number
crl_number="$(printf '%02x\n' $((0x${crl_number##*=} +1 )))"

# Add a leading 0 if we have an odd number of digits
(( ${#crl_number} % 2 == 0 )) || crl_number="0${crl_number}"
echo "$crl_number" >/tmp/crlnumber

"$PUPPET_BIN"/openssl ca -config /tmp/openssl.cnf -gencrl -out /tmp/intermediate_crl.pem

# For a multi-chain crl, cat the new crl with the root.  Otherwise, use only the new crl.
if (( cert_num > 1 )); then
  cat /tmp/intermediate_crl.pem "$root_crl" >/tmp/new_crl.pem

  cp /tmp/new_crl.pem "$ssldir"/ca/ca_crl.pem
  cp /tmp/new_crl.pem "$ssldir"/crl.pem
else
  cp /tmp/intermediate_crl.pem "$ssldir"/ca/ca_crl.pem
  cp /tmp/intermediate_crl.pem "$ssldir"/crl.pem
fi

# Send errors to our temp file
if $run_puppet_agent; then
  "$PUPPET_BIN"/puppet agent --onetime --no-daemonize --no-usecacheonfailure --logdest "$_tmp" --log_level err
  success '{ "status": "success", "message": "CRL truncated and Puppet agent run completed"}'
else
  success '{ "status": "success", "message": "CRL truncated. Puppet agent run was skipped"}'
fi
