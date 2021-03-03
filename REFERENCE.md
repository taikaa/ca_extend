# Reference

## Configuration

### ssh

Bolt defaults to using the `ssh` transport, which will in turn use `~/.ssh/config` for options such as `username` and `private-key`.

Below is a sample `config` file and command.

```
Host pe-*
  User centos
  Port 22
  PasswordAuthentication no
  IdentityFile /home/adrian/.ssh/id_rsa-acceptance
  IdentitiesOnly yes
  LogLevel ERROR
```

```bash
$ bolt plan run ca_extend::upload_ca_cert cert=/tmp/ca.pem --run-as root --targets pe-agent.example.com
{
  "success": {
    "pe-agent.example.com": {
      "_output": "Uploaded '/tmp/ca.pem' to 'pe-agent.example.com:/etc/puppetlabs/puppet/ssl/certs/ca.pem'"
    }
  }
}
```

### Inventory

See the Bolt [inventory file](https://puppet.com/docs/bolt/latest/inventory_file.html) documentation for a full reference.

Below is a sample inventory created using [bolt-inventory-pdb](https://puppet.com/docs/bolt/latest/inventory_file_generating.html) and example commands.

```bash
$ cat pdb.yaml
---
query: "inventory[certname] {}"
groups:
- name: windows
  query: "inventory[certname] { facts.os.family = 'windows' }"
  config:
    transport: winrm
    winrm:
      user: Administrator
      password: foo
      ssl: false
- name: linux
  query: "inventory[certname] { facts.kernel = 'Linux' }"
  config:
    transport: ssh
    ssh:
      user: centos
      private-key: ~/.ssh/id_rsa-acceptance
      host-key-check: false
```

```bash
$ /opt/puppetlabs/bolt/bin/bolt-inventory-pdb pdb.yaml -o ~/.puppetlabs/bolt/inventory.yaml
```

```bash
$ cat ~/.puppetlabs/bolt/inventory.yaml
---
query: inventory[certname] {}
groups:
- name: windows
  query: inventory[certname] { facts.os.family = 'windows' }
  config:
    transport: winrm
    winrm:
      user: Administrator
      password: foo
      ssl: false
  nodes:
  - pe-agent-windows.example.com
- name: linux
  query: inventory[certname] { facts.kernel = 'Linux' }
  config:
    transport: ssh
    ssh:
      user: centos
      private-key: "~/.ssh/id_rsa-acceptance"
      host-key-check: false
  nodes:
  - pe-master.example.com
  - pe-agent.example.com
  - pe-compiler.example.com
nodes:
- pe-master.example.com
- pe-compiler.example.com
- pe-agent.example.com
- pe-agent-windows.example.com
```

```bash
$ bolt command run hostname --targets linux
Started on pe-master.example.com...
Started on pe-compiler.example.com...
Started on pe-agent.example.com...
Finished on pe-master.example.com:
  STDOUT:
    pe-master.example.com
Finished on pe-compiler.example.com:
  STDOUT:
    pe-compile.example.com
Finished on pe-agent.example.com:
  STDOUT:
    pe-agent.example.com
Successful on 3 nodes: pe-master.example.com,pe-agent.example.com,pe-compiler.example.com
Ran on 3 nodes in 0.62 seconds
```

```bash
$ bolt command run hostname --targets windows
Started on pe-agent-windows.example.com...
Finished on pe-agent-windows.example.com:
  STDOUT:
    pe-agent-windows.example.com
Successful on 1 node: pe-agent-windows.example.com
Ran on 1 node in 0.70 seconds
```

## Plans

### `ca_extend::extend_ca_cert`

#### Arguments

* master - Fully-qualified domain name of the Master acting as the Certificate Authority
* compile_masters - Optional comma-separated list of fully-qualified domain names of Compilers
* regen_primary_cert - Boolean for whether to also regenrate the primary server certificate.  Defaults to `false`

#### Steps

* Runs the `service` task to stop the `puppet` and `pe-puppetserver` services on the (Primary) Master
* Runs the `ca_extend::extend_ca_cert` task to output the new CA certificate to a file, and return the path to the file and a base64 encoded string of its contents
* Runs the `ca_extend::configure_master` task to backup the `ssl` directory to `/var/puppetlabs/backups`, copy the new CA certificate in-place, and configure the Master to use that certificate
* Decodes the CA certificate's contents and outputs it to a temp file
* Uploads the new CA certificate to any Compilers and configures them to use that certificate

#### Output

All of the steps in this plan are critical to extending the certificate, so the plan will fail if any step fails.
The output consists of Bolt logging messages and any failures of the steps involved.

### Example

```bash
$ bolt plan run ca_extend::extend_ca_cert --targets pe-master.example.com compile_masters=pe-compiler.example.com --run-as root
Starting: plan ca_extend::extend_ca_cert
Starting: command 'echo "test" | base64 -w 0 - &>/dev/null' on localhost
Finished: command 'echo "test" | base64 -w 0 - &>/dev/null' with 0 failures in 0.0 sec
INFO: Stopping puppet services on pe-master.example.com
Starting: task service on pe-master.example.com
Finished: task service with 0 failures in 0.85 sec
Starting: task service on pe-master.example.com
Finished: task service with 0 failures in 1.95 sec
INFO: Extending CA certificate on pe-master.example.com
Starting: task ca_extend::extend_ca_cert on pe-master.example.com
Finished: task ca_extend::extend_ca_cert with 0 failures in 2.92 sec
INFO: Configuring pe-master.example.com to use the extended CA certificate
Starting: task ca_extend::configure_master on pe-master.example.com
Finished: task ca_extend::configure_master with 0 failures in 95.72 sec
Starting: task service on pe-master.example.com
Finished: task service with 0 failures in 1.64 sec
INFO: Stopping puppet services on compilers (pe-compiler.example.com)
INFO: Configuring compilers (pe-compiler.example.com) to use the extended CA certificate
Starting: file upload from /tmp/ca.pem to /etc/puppetlabs/puppet/ssl/certs/ca.pem on pe-compiler.example.com
Finished: file upload from /tmp/ca.pem to /etc/puppetlabs/puppet/ssl/certs/ca.pem with 0 failures in 0.59 sec
Starting: task run_agent on pe-compiler.example.com
Finished: task run_agent with 0 failures in 44.34 sec
INFO: Extended CA certificate decoded and stored at /tmp/ca.pem
INFO: Run the 'ca_extend::upload_ca_cert' plan to distribute the extended CA certificate to agents
Finished: plan ca_extend::extend_ca_cert in 148.06 sec
```

### `ca_extend::upload_ca_cert`

#### Arguments

*  cert - Location of the new CA certificate on disk.

This plan accepts any valid TargetSpec(s) specified by the `--targets` option.

#### Steps

* Collects facts from agents and separates them into groups of \*nix and Windows
* Runs `upload_file` on each list of agents to distribute the CA certificate
* Constructs a JSON formatted object of the results of the uploads and returns it

#### Output

The output of this plan is a JSON object with two keys: `success` and `failure`. 
Each key contains any number of objects consisting of the agent certname and the output of the `upload_file` command.

### Example

```bash
$ bolt plan run ca_extend::upload_ca_cert cert=/tmp/ca.pem --run-as root --query 'inventory { }'
Starting: plan ca_extend::upload_ca_cert
Starting: plan ca_extend::get_agent_facts
Starting: install puppet and gather facts on pe-master.example.com, pe-compiler.example.com, pe-agent.example.com, pe-agent-windows.example.com
Finished: install puppet and gather facts with 0 failures in 9.33 sec
Finished: plan ca_extend::get_agent_facts in 9.33 sec
Starting: plan facts
Starting: task facts on pe-master.example.com, pe-compiler.example.com, pe-agent.example.com, pe-agent-windows.example.com
Finished: task facts with 0 failures in 6.27 sec
Finished: plan facts in 6.31 sec
Starting: file upload from /tmp/ca.pem to /etc/puppetlabs/puppet/ssl/certs/ca.pem on pe-master.example.com, pe-compiler.example.com, pe-agent.example.com
Finished: file upload from /tmp/ca.pem to /etc/puppetlabs/puppet/ssl/certs/ca.pem with 0 failures in 0.66 sec
Starting: file upload from /tmp/ca.pem to C:\ProgramData\PuppetLabs\puppet\etc\ssl\certs\ca.pem on pe-agent-windows.example.com
Finished: file upload from /tmp/ca.pem to C:\ProgramData\PuppetLabs\puppet\etc\ssl\certs\ca.pem with 0 failures in 1.07 sec
Finished: plan ca_extend::upload_ca_cert in 17.41 sec
{
  "success": {
    "pe-master.example.com": {
      "_output": "Uploaded '/tmp/ca.pem' to 'pe-master.example.com:/etc/puppetlabs/puppet/ssl/certs/ca.pem'"
    },
    "pe-compiler.example.com": {
      "_output": "Uploaded '/tmp/ca.pem' to 'pe-compiler.example.com:/etc/puppetlabs/puppet/ssl/certs/ca.pem'"
    },
    "pe-agent.example.com": {
      "_output": "Uploaded '/tmp/ca.pem' to 'pe-agent.example.com:/etc/puppetlabs/puppet/ssl/certs/ca.pem'"
    },
    "pe-agent-windows.example.com": {
      "_output": "Uploaded '/tmp/ca.pem' to 'pe-agent-windows.example.com:C:\\ProgramData\\PuppetLabs\\puppet\\etc\\ssl\\certs\\ca.pem'"
    }
  }
}
```

## Tasks

### `ca_extend::check_ca_expiry`

#### Arguments

* cert - Optional location of CA certificate on disk to check. Defaults to `/etc/puppetlabs/puppet/ssl/certs/ca.pem`.
* date - Optional YYYY-MM-DD format date against which to check for expiration. Defaults to three months from today.

This task accepts any valid TargetSpec(s) specified by the `--targets` option.
Can be run on any \*nix agent node or the Master.

#### Steps

* Uses Unix `openssl` and `date` to determine if the CA certificate will expire.

#### Output

A JSON object with the status and expiration date of the CA certificate.

### Example

```bash
{
  "status": "valid",
  "expiry date": "Feb 16 01:00:09 2034 GMT"
}
```

### `ca_extend::check_agent_expiry`

#### Arguments

* date - Optional YYYY-MM-DD format date against which to check for expiration. Defaults to three months from today.

This task accepts any valid TargetSpec(s) specified by the `--targets` option.
Should be run on the Master.

#### Steps

* Uses Unix `openssl` and `date` to determine if the agent certificates in `/etc/puppetlabs/puppet/ssl/ca/signed/` will expire.

#### Output

A JSON object with keys for valid and expiring certificates.

### Example

```bash
  {
    "valid": [
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-master.example.com.pem",
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-compiler.example.com.pem",
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-agent.example.com.pem",
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-agent.example.com",
      "/etc/puppetlabs/puppet/ssl/ca/signed/pe-agent-windows.example.com.pem",
    ],
    "expiring": [

    ]
  }
```
