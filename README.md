
# ca_extend

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with ca_extend](#setup)
3. [Usage - Configuration options and additional functionality](#usage)

## Description

A set of Plans and Tasks to extend the expiration date of the certificate for the certificate authority in Puppet Enterprise.

## Dependencies

*  A [Bolt installation](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 1.8.0
*  A `base64` binary on the master and client machine which supports the `-w` flag
*  `bash` >= 4.0
*  [puppetlabs-stdlib](https://puppet.com/docs/bolt/latest/bolt_installing.html) >= 3.2.0 < 6.0.0

## Configuration

### Inventory

This module works best with a Bolt [inventory file](https://puppet.com/docs/bolt/latest/inventory_file.html) to support simultaneous uploads to \*nix and Windows agents.  See the Bolt documentation for how to configure the inventory.  See the `REFERENCE.md` for a sample inventory file.

Alternatively, one can use an `ssh` config file if only using this protocol to connect to agents.  Bolt defaults to using `ssh`, which in turn will use `~/.ssh/config` for options such as the username and identity file.

### Connecting to PuppetDB

Another convenient way to specify targets for the `ca_extend::upload_ca_cert` plan is by connecting Bolt to [PuppetDB](https://puppet.com/docs/bolt/latest/bolt_command_reference.html#command-options), after which the [--query](https://puppet.com/docs/bolt/latest/bolt_command_reference.html#command-options) can be used to specify a node list. See `REFERENCE.md` for an example.

## Usage

The functionality of this module is divided into two main plans:

*  `ca_extend::extend_ca_cert` to extend the certificate and configure the master and any compile masters to use the new certificate
*  `ca_extend::upload_ca_cert` to distribute the certificate to any number of agents.  Any protocol supported by Bolt can be used, such as `ssh`, `winrm`, or `PCP`.

### Syntax

```
bolt plan run ca_extend::extend_ca_cert master=<master_fqdn> compile_masters=<comma_separated_compile_master_fqdns>
```

```
bolt plan run ca_extend::upload_ca_cert cert=<path_to_cert> --nodes <TargetSpec>
```
See `REFERENCE.md` for example commands
