#!/bin/bash

# Puppet CA extension script
#
# This script uses the Puppet CA certificates and private
# keys to generate new CA certificates with extended 15 year
# lifespans.
#
# This script operates on 2-certificate CA bundles used by
# Puppet 6 and later in addition to single-certificate
# bundles used by Puppet 5 and earlier.
#
# This script requires that the default locations for
# the Puppet cadir and files underneath it are in use.
#
# Externally issued CA certificates are not supported.

set -e

PUPPET_BIN='/opt/puppetlabs/puppet/bin'

ca_bundle=$("${PUPPET_BIN}/puppet" config print --section master cacert)
ca_dir=$(dirname "${ca_bundle}")

printf 'CA bundle file: %s\n' "${ca_bundle}" >&2

printf '\n Checking CA bundle length...\n' >&2
chain_length=$(grep -cF 'BEGIN CERTIFICATE' "${ca_bundle}")

if (( chain_length > 2 )); then
  printf '%s certificates were found in: %s\n' "${chain_length}" "${ca_bundle}" >&2
  printf 'This script only works on CA bundles that contain one or two certificates.\n' >&2
  exit 1
elif (( chain_length == 2 )); then
  printf '2 entry Puppet CA detected in: %s\n' "${ca_bundle}" >&2
  root_key="${ca_dir}/root_key.pem"
  intermediate_key="${ca_dir}/ca_key.pem"

  [[ -r "${root_key}" ]] || {
    printf 'ERROR: The Root CA key file is not readable: %s\n' "${root_key}" >&2
    printf 'This script must be run as root and does not support externally issued CA certs.\n' >&2
    exit 1
  }

  [[ -r "${intermediate_key}" ]] || {
    printf 'ERROR: The Intermediate CA key file is not readable: %s\n' "${root_key}" >&2
    exit 1
  }
elif (( chain_length == 1 )); then
  printf '1 entry Puppet CA detected in: %s\n' "${ca_bundle}" >&2
  root_key="${ca_dir}/ca_key.pem"

  [[ -r "${root_key}" ]] || {
    printf 'ERROR: The Root CA key file is not readable: %s\n' "${root_key}" >&2
    printf 'This script must be run as root and does not support externally issued CA certs.\n' >&2
    exit 1
  }
else
  printf 'ERROR: No certificates detected in: %s\n' "${ca_bundle}" >&2
  exit 1
fi


# Build a temporary directory with files required to renew the CA cert.

workdir=$(mktemp -d -t puppet_ca_extend.XXX)
printf 'Using working directory: %s\n' "${workdir}" >&2

touch "${workdir}/inventory"
touch "${workdir}/inventory.attr"
cat <<EOT > "${workdir}/openssl.cnf"
[ca]
default_ca=ca_settings

[ca_settings]
serial=${workdir}/serial
new_certs_dir=${workdir}
database=${workdir}/inventory
default_md=sha256
policy=ca_policy
x509_extensions=cert_extensions

[ca_policy]
commonName=supplied

[cert_extensions]
basicConstraints=critical,CA:TRUE
keyUsage=keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always
EOT

# Separate CA bundle out into individual certificates
csplit -szf "${workdir}/puppet-ca-cert-" "${ca_bundle}" '/-----BEGIN CERTIFICATE-----/' '{*}'
ca_certs=("${workdir}"/puppet-ca-cert-*)


# Match keys up with certificates
root_cert=''

root_fingerprint=$("${PUPPET_BIN}/openssl" rsa -in "${root_key}" -noout -modulus|cut -d= -f2-)
for ca_cert in "${ca_certs[@]}"; do
  ca_fingerprint=$("${PUPPET_BIN}/openssl" x509 -in "${ca_cert}" -noout -modulus|cut -d= -f2-)
  if [[ "${ca_fingerprint}" == "${root_fingerprint}" ]]; then
    root_cert="${ca_cert}"
    break
  fi
done

[[ -n "${root_cert}" ]] || {
  printf 'ERROR: Could not find a certificate matching key %s\n' "${root_key}" >&2
  printf 'Checked: %s\n\t%s\n' "${ca_certs[@]}" >&2

  exit 1
}

if (( chain_length == 2 )); then
  intermediate_cert=''

  intermediate_fingerprint=$("${PUPPET_BIN}/openssl" rsa -in "${intermediate_key}" -noout -modulus|cut -d= -f2-)
  for ca_cert in "${ca_certs[@]}"; do
    ca_fingerprint=$("${PUPPET_BIN}/openssl" x509 -in "${ca_cert}" -noout -modulus|cut -d= -f2-)
    if [[ "${ca_fingerprint}" == "${intermediate_fingerprint}" ]]; then
      intermediate_cert="${ca_cert}"
      break
    fi
  done

  [[ -n "${intermediate_cert}" ]] || {
    printf 'ERROR: Could not find a certificate matching key %s\n' "${intermediate_key}" >&2
    printf 'Checked: %s\n\t%s\n' "${ca_certs[@]}" >&2

    exit 1
  }
fi


# Extend CA certs

# Compute start and end dates for new certificates.
# Formats the year as YY instead of YYYY because the latter isn't supported
# until OpenSSL 1.1.1.
start_date=$(date -u --date='-24 hours' '+%y%m%d%H%M%SZ')
end_date=$(date -u --date='+15 years' '+%y%m%d%H%M%SZ')

root_subject=$("${PUPPET_BIN}/openssl" x509 -in "${root_cert}" -noout -subject|cut -d= -f2-)
root_issuer=$("${PUPPET_BIN}/openssl" x509 -in "${root_cert}" -noout -issuer|cut -d= -f2-)
root_enddate=$("${PUPPET_BIN}/openssl" x509 -in "${root_cert}" -noout -enddate|cut -d= -f2-)
root_serial_num=$("${PUPPET_BIN}/openssl" x509 -in "${root_cert}" -noout -serial|cut -d= -f2-)

[[ "${root_subject}" = "${root_issuer}" ]] || {
  printf 'ERROR: Root CA cert is not self-signed: %s\n' "${root_cert}" >&2
  printf 'Subject: %s\n' "${root_subject}" >&2
  printf 'Issuer: %s\n' "${root_issuer}" >&2
  printf 'This script does not support externally-issued CAs.' >&2

  exit 1
}

printf '\nExtending: %s\n' "${root_cert}" >&2
printf 'Subject: %s\n' "${root_subject}" >&2
printf 'Issuer: %s\n' "${root_issuer}" >&2
printf 'Serial: %s\n' "${root_serial_num}" >&2
printf 'End-Date: %s\n' "${root_enddate}" >&2

# Generate a signing request from the existing certificate
"${PUPPET_BIN}/openssl" x509 -x509toreq \
  -in "${root_cert}" \
  -signkey "${root_key}" \
  -out "${workdir}/root_ca.csr.pem"

printf '%s' "${root_serial_num}" > "${workdir}/serial"

yes | "${PUPPET_BIN}/openssl" ca \
  -notext \
  -in "${workdir}/root_ca.csr.pem" \
  -keyfile "${root_key}" \
  -config "${workdir}/openssl.cnf" \
  -selfsign \
  -startdate "${start_date}" \
  -enddate "${end_date}" \
  -out "${workdir}/root_ca.renewed.pem" >&2

if (( chain_length == 2 )); then
  intermediate_subject=$("${PUPPET_BIN}/openssl" x509 -in "${intermediate_cert}" -noout -subject|cut -d= -f2-)
  intermediate_issuer=$("${PUPPET_BIN}/openssl" x509 -in "${intermediate_cert}" -noout -issuer|cut -d= -f2-)
  intermediate_enddate=$("${PUPPET_BIN}/openssl" x509 -in "${intermediate_cert}" -noout -enddate|cut -d= -f2-)
  intermediate_serial_num=$("${PUPPET_BIN}/openssl" x509 -in "${intermediate_cert}" -noout -serial|cut -d= -f2-)

  [[ "${intermediate_issuer}" == "${root_issuer}" ]] || {
    printf 'ERROR: Intermediate CA cert is not issued by Root CA: %s\n' "${intermediate_cert}" >&2
    printf 'Subject: %s\n' "${intermediate_subject}" >&2
    printf 'Issuer: %s\n' "${intermediate_issuer}" >&2
    printf 'This script does not support externally-issued CAs.' >&2

    exit 1
  }

  printf '\nExtending: %s\n' "${intermediate_cert}" >&2
  printf 'Subject: %s\n' "${intermediate_subject}" >&2
  printf 'Issuer: %s\n' "${intermediate_issuer}" >&2
  printf 'Serial: %s\n' "${intermediate_serial_num}" >&2
  printf 'End-Date: %s\n' "${intermediate_enddate}" >&2

  # Generate a signing request from the existing certificate
  "${PUPPET_BIN}/openssl" x509 -x509toreq \
    -in "${intermediate_cert}" \
    -signkey "${intermediate_key}" \
    -out "${workdir}/intermediate_ca.csr.pem"

  printf '%s' "${intermediate_serial_num}" > "${workdir}/serial"

  yes | "${PUPPET_BIN}/openssl" ca \
    -notext \
    -in "${workdir}/intermediate_ca.csr.pem" \
    -cert "${workdir}/root_ca.renewed.pem" \
    -keyfile "${root_key}" \
    -config "${workdir}/openssl.cnf" \
    -startdate "${start_date}" \
    -enddate "${end_date}" \
    -out "${workdir}/intermediate_ca.renewed.pem" >&2
fi


# Generate output bundle
new_ca_bundle="${ca_dir}/ca_crt-expires-${end_date}.pem"

if (( chain_length == 2 )); then
  cat "${workdir}/intermediate_ca.renewed.pem" \
      "${workdir}/root_ca.renewed.pem" > "${new_ca_bundle}"
else
  cat "${workdir}/root_ca.renewed.pem" > "${new_ca_bundle}"
fi

printf '\nRenewed CA certificates.\n' >&2
printf '%s\n' "${new_ca_bundle}"
