# ca_extend

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with ca_extend](#setup)
3. [Usage - Configuration options and additional functionality](#usage)

## Description

A set of Plans and Tasks to extend the expiration date of the certificate for the certificate authority in Puppet Enterprise and distribute the certificate to agent nodes.

The functionality of this module is divided into two main plans:

*  `ca_extend::extend_ca_cert`
    * Extends the CA certificate and configures the master and any compile masters to use the new certificate
*  `ca_extend::upload_ca_cert`
    * Distributes the certificate to any number of agents.  Any protocol supported by Bolt can be used, such as `ssh`, `winrm`, or `PCP`.

Regardless of whether the CA cert has passed expiration or not, the `extend_ca_cert` plan may be used to extend its expiration date in-place and configure the master and compilers to use it.

After the CA is functional again (or if it had yet to expire), there are two options for distributing the new cert to agents.

* Using the `ca_extend::upload_ca_cert` plan or another method to copy the new `ca.pem` into place on agents.
* Deleting `ca.pem` from agents and letting them download the file as part of the next Puppet agent run.  The agent will re-download this file only if it is absent, so it must be deleted to get a new copy using this method.

There are also two complementary tasks to check the expiry of the CA cert and any agent certificates.

* `ca_extend::check_agent_expiry`
    * Checks if any agent certificates expire by a certain date.  Defaults to 3 months from today
* `ca_extend::check_ca_expiry`
    * Checks if the CA certificate expires by a certain date.  Defaults to 3 months from today

## Setup
This module requires a [Bolt installation](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 1.8.0 on either a client machine or the Puppet master

The recommended installation procedure for this module is to use a [Bolt Puppetfile](https://puppet.com/docs/bolt/latest/installing_tasks_from_the_forge.html#task-8928).  From within a [Boltdir](https://puppet.com/docs/bolt/latest/bolt_project_directories.html#embedded-project-directory), specify this module and `puppetlabs-stdlib` as dependencies and run `bolt puppetfile install`.  For example, to install Bolt and the required modules on an EL 7 master:

```
sudo rpm -Uvh https://yum.puppet.com/puppet-tools-release-el-7.noarch.rpm
sudo yum install puppet-bolt
```

```
mkdir -p ~/Boltdir
cd !$

cat >>Puppetfile <<EOF
mod 'puppetlabs-stdlib'

mod 'puppetlabs-ca_extend'
EOF

bolt puppetfile install
```

## Dependencies

*  A [Bolt installation](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 1.8.0
*  [puppetlabs-stdlib](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 3.2.0 < 6.0.0
*  A `base64` binary on the master which supports the `-w` flag
*  `bash` >= 4.0 on the master

## Configuration

### Inventory

This module works best with a Bolt [inventory file](https://puppet.com/docs/bolt/latest/inventory_file.html) to support simultaneous uploads to \*nix and Windows agents.  See the Bolt documentation for how to configure the inventory.  See the `REFERENCE.md` for a sample inventory file.

Alternatively, one can use an `ssh` config file if only using this protocol to connect to agents.  Bolt defaults to using `ssh`, which in turn will use `~/.ssh/config` for options such as the username and identity file.

### Connecting to PuppetDB

Another convenient way to specify targets for the `ca_extend::upload_ca_cert` plan is by connecting Bolt to [PuppetDB](https://puppet.com/docs/bolt/latest/bolt_connect_puppetdb.html), after which the [--query](https://puppet.com/docs/bolt/latest/bolt_command_reference.html#command-options) can be used to specify a node list. See `REFERENCE.md` for an example.

### Examples

```
bolt plan run ca_extend::extend_ca_cert master=<master_fqdn> compile_masters=<comma_separated_compile_master_fqdns>
```
```
bolt plan run ca_extend::upload_ca_cert cert=<path_to_cert> --nodes <TargetSpec>
```
```
bolt task run ca_extend::check_ca_expiry --nodes <TargetSpec>
```
```
bolt task run ca_extend::check_agent_expiry --nodes <TargetSpec>
```
See `REFERENCE.md` for more detailed example commands
