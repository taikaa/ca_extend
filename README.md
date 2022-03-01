# ca_extend

#### Table of Contents

1. [Overview](#overview)
1. [Description - What the module does and why it is useful](#description)
1. [Setup - The basics of getting started with this module](#setup)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing](#reference)
1. [Development - Guide for contributing to the module](#How-to-Report-an-issue-or-contribute-to-the-module)

## Overview

This module can extend a certificate authority (CA) that's about to expire or has already expired.

A Puppet CA certificate is only valid for a finite time (a new installation of PE 2019.x / Puppet 6.x will create a 15 year CA, while earlier versions will create a 5 year CA; and upgrading does not extend the CA.), after which it expires.
When a CA certificate expires, Puppet services will no longer accept any certificates signed by that CA, and your Puppet infrastructure will immediately stop working.

If your CA certificate is expiring soon (or it's already expired), you need to:

* Generate a new CA certificate using the existing CA keypair.
* Distribute the new CA certificate to agents.

This module can automate those tasks.

## Description

This module is composed of Plans and Tasks to extend the expiration date of the CA certificate in Puppet Enterprise (and Puppet Open Source) and distribute that CA certificate to agents.

Note that, with Puppet Open Source, if the CA certificate is only used by the Puppet CA and no other integrations, there is no further action to take after using the two Plans.
However, if it is used for other integrations (such as SSL encrypted PuppetDB traffic) then those integrations will need to have their copy of the CA certificate updated.
If the CA certificate is stored in any keystores, those will also need to be updated.

The functionality of this module is composed into two Plans:

*  `ca_extend::extend_ca_cert`
    * Extend the CA certificate and configure the primary Puppet server and any Compilers to use that extended certificate.
*  `ca_extend::upload_ca_cert`
    * Distribute the CA certificate to agents using any transport supported by Puppet Bolt, such as `ssh`, `winrm`, or `pcp`.

Regardless of whether the CA certificate is expired, the `extend_ca_cert` plan may be used to extend its expiration date in-place and configure the primary Puppet server and any Compilers to use it.

After the CA certificate has been extended, there are two methods for distributing it to agents.

* Using the `ca_extend::upload_ca_cert` plan or another method to copy the CA certificate to agents.
* Manually deleting `ca.pem` on agents and letting them download that file as part of the next Puppet agent run. The agent will download that file only if it is absent, so it must be deleted to use this method.

There are also two complementary tasks to check the expiration date of the CA certificate or any agent certificates.

* `ca_extend::check_ca_expiry`
    * Checks if the CA certificate expires by a certain date. Defaults to three months from today.
* `ca_extend::check_agent_expiry`
    * Checks if any agent certificate expires by a certain date. Defaults to three months from today.

** If the CA certificate is expiring or expired, you must extend it as soon as possible. **

## Setup

This module requires [Puppet Bolt](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 1.38.0 on either on the primary Puppet server or a workstation with connectivity to the primary.

The installation procedure will differ depending on the version of Bolt.  If possible, using Bolt >= 3.0.0 is recommended.  For example, this will install the latest Bolt version on EL 7.

```bash
sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm
sudo yum install puppet-bolt
```

The following two sections show how to install the module dependencies depending on the installed version of Bolt.

### Bolt >= 1.38.0 < 3.0.0

The recommended procedure for these versions is to use a [Bolt Puppetfile](https://puppet.com/docs/bolt/latest/installing_tasks_from_the_forge.html#task-8928).
From within a [Boltdir](https://puppet.com/docs/bolt/latest/bolt_project_directories.html#embedded-project-directory), specify this module and `puppetlabs-stdlib` as dependencies and run `bolt puppetfile install`.  For example:

```bash
mkdir -p ~/Boltdir
cd ~/Boltdir

cat >>Puppetfile <<EOF
mod 'puppetlabs-stdlib'

mod 'puppetlabs-ca_extend'
EOF

bolt puppetfile install
```

### Bolt >= 3.0.0

The recommended procedure for these versions is to use a Bolt Project.  When creating a [Bolt project](https://puppet.com/docs/bolt/latest/bolt_project_directories.html#embedded-project-directory), specify this module and `puppetlabs-stdlib` as dependencies and initialize the project.  For example:

```bash
sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm
sudo yum install puppet-bolt
```

If your primary Puppet server or workstation has internet access, the project can be initialized with the needed dependencies with the following:

```bash
mkdir ca_extend
cd ca_extend

bolt project init expiry --modules puppetlabs-stdlib,puppetlabs-ca_extend
```

Otherwise, if your primary Puppet server or workstation operates behind a proxy, initialize the project without the `--modules` option:

```bash
mkdir ca_extend
cd ca_extend

bolt project init expiry
```

Then edit your `bolt-project.yaml` to use the proxy according to the [documentation](https://puppet.com/docs/bolt/latest/bolt_installing_modules.html#install-modules-using-a-proxy).  Next, add the module dependencies to `bolt-project.yaml`:

```yaml
---
name: expiry
modules:
  - name: puppetlabs-stdlib
  - name: puppetlabs-ca_extend

```

Finally, install the modules.

```bash
bolt module install
```

See the "Usage" section for how to run the tasks and plans remotely or locally on the primary Puppet server.

### Dependencies

*  A [Puppet Bolt](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 1.38.0
*  [puppetlabs-stdlib](https://puppet.com/docs/bolt/latest/bolt_installing.html)
*  A `base64` binary on the primary Puppet server which supports the `-w` flag
*  `bash` >= 4.0 on the primary Puppet server

### Configuration

#### Inventory

This module works best with a Bolt [inventory file](https://puppet.com/docs/bolt/latest/inventory_file.html) to allow for simultaneous uploads to \*nix and Windows agents.
See the Bolt documentation for how to configure an inventory file.

Alternatively, you can use an `ssh` config file if you will only use that transport to upload the CA certificate to agents.
Bolt defaults to using the `ssh` transport, which in turn will use `~/.ssh/config` for options such as `username` and `private-key`.

#### PuppetDB

A convenient way to specify targets for the `ca_extend::upload_ca_cert` plan is by connecting Bolt to [PuppetDB](https://puppet.com/docs/bolt/latest/bolt_connect_puppetdb.html). Either [--query](https://puppet.com/docs/bolt/latest/bolt_command_reference.html#command-options) can be used to specify targets as a command line option or the [PuppetDB plugin](https://puppet.com/docs/bolt/latest/supported_plugins.html#puppetdb) can be used to specify targets within the Bolt inventory file (`inventory.yaml`). Examples of each are included below.

##### Example querying PuppetDB for all nodes using the `--query` command line option:

```
bolt plan run ca_extend::upload_ca_cert cert=$(puppet config print localcacert) --query "nodes[certname] {}"
```

##### Example querying PuppetDB within `inventory.yaml`:

This example queries PuppetDB for webserver nodes whose certnames start with `web` 

``` yaml
groups:
  - name: webservers
    targets:
      - _plugin: puppetdb
        query: 'nodes[certname] { certname ~ "^web" }'
        target_mapping:
          uri: certname
```

```
bolt plan run ca_extend::upload_ca_cert cert=$(puppet config print localcacert) --targets webservers
```

#### PCP

Note that you cannot use the Bolt `pcp` transport if your CA certificate has already expired, as the PXP-Agent service itself depends upon a valid CA certificate.

## Usage

### ca_extend::extend_ca_cert Plan

First, check the expiration of the Puppet agent certificate by running the following command as root on the primary Puppet server:

```bash
/opt/puppetlabs/puppet/bin/openssl x509 -in "$(/opt/puppetlabs/bin/puppet config print hostcert)" -enddate -noout
```

If, and only if, the `notAfter` date printed has already passed, then the primary Puppet server certificate has expired and must be cleaned up before the CA can be regenerated.  This can be accomplished by passing `regen_primary_cert=true` to the `ca_extend::extend_ca_cert` plan.

```bash
bolt plan run ca_extend::extend_ca_cert regen_primary_cert=true --targets <primary_fqdn> compilers=<comma_separated_compiler_fqdns> --run-as root
```

Note that if you are running `extend_ca_cert` locally on the primary Puppet server, you can avoid potential Bolt transport issues by specifying `--targets local://hostname`, e.g.

```bash
bolt plan run ca_extend::extend_ca_cert --targets local://hostname --run-as root
```

### ca_extend::upload_ca_cert Plan

You can use this plan with `cert` parameter to specify the location of the updated CA cert and distribute it to the nodes specified in the `targets` parameter

```bash
bolt plan run ca_extend::upload_ca_cert cert=<path_to_cert> --targets <TargetSpec>
```

### ca_extend::check_ca_expiry Task

You can use this task to check the ca cert expiry on the `primary` mainly but you can also use it to check that a remote CA cert has been updated after using any means to update an expired CA cert on an agent.

```bash
bolt task run ca_extend::check_ca_expiry --targets <TargetSpec>
```

### ca_extend::check_agent_expiry Task

You can use this task to categorize all PE certs in a PE environment as part of a valid or expiring section based on a customizable date in the future (default 3 months from now). This task runs against a `primary` server and checks all certs under `/etc/puppetlabs/puppet/ssl/ca/signed` as the single source of truth for the PE environment and splits the certs between a valid section or expiring section.

```bash
bolt task run ca_extend::check_agent_expiry --targets local://hostname
```

As such, the following output illustrates that all available certs in `/etc/puppetlabs/puppet/ssl/ca/signed` are valid and nothing is expiring in the next 3 months.

```bash
[root@pe-server-7a5b76-0 ca_extend]# bolt task run ca_extend::check_agent_expiry --targets local://hostname
Started on local://pe-server-7a5b76-0.us-west1-c.internal...
Finished on local://pe-server-7a5b76-0.us-west1-c.internal:
  {
    "valid": [
      "/etc/puppetlabs/puppet/ssl/ca/signed/console-cert.pem",
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-node-7a5b76-0.us-west1-c.internal.pem",
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-server-7a5b76-0.us-west1-c.internal.pem",
      "/etc/puppetlabs/puppet/ssl/ca/signed/win19-06d5fc-0.us-west1-c.internal.pem"
    ],
    "expiring": [

    ]
  }
Successful on 1 target: local://pe-server-7a5b76-0.us-west1-c.internal
Ran on 1 target in 1.32 sec
```

See `REFERENCE.md` for more detailed examples.

## Reference

Puppet's security is based on a PKI using X.509 certificates.

This module's `ca_extend::extend_ca_cert` plan creates a new self-signed CA certificate using the same keypair as the prior self-signed CA. The new CA has the same:

* Keypair.
* Subject.
* Issuer.
* X509v3 Subject Key Identifier (the fingerprint of the public key).

The new CA has a different:

* Authority Key Identifier (just the serial number, since it's self-signed).
* Validity period (the point of the whole exercise).
* Signature (since we changed the serial number and validity period).

Since Puppet's services (and other services that use Puppet's PKI) validate certificates by trusting a self-signed CA and comparing its public key to the Signatures and Authority Key Identifiers of the certificates it has issued,
it's possible to issue a new self-signed CA certificate based on a prior keypair without invalidating any certificates issued by the old CA.
Once you've done that, it's just a matter of delivering the new CA certificate to every participant in the PKI.

## How to Report an issue or contribute to the module

If you are a PE user and need support using this module or are encountering issues, our Support team would be happy to help you resolve your issue and help reproduce any bugs. Just raise a ticket on the [support portal](https://support.puppet.com/hc/en-us/requests/new).

If you have a reproducible bug or are a community user you can raise it directly on the Github issues page of the module [here.](https://github.com/puppetlabs/ca_extend/issues) We also welcome PR contributions to improve the module. Please see further details about contributing [here](https://puppet.com/docs/puppet/7.5/contributing.html#contributing_changes_to_module_repositories)
