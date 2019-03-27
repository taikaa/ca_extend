Example

```
$ bolt plan run ca_regen::ca_regen master=pe-201815-master compile_masters=pe-201815-compile --run-as root
Starting: plan ca_regen::ca_regen
INFO: Stopping puppet and pe-puppetserver services on pe-201815-master
Starting: task service on pe-201815-master
Finished: task service with 0 failures in 1.0 sec
Starting: task service on pe-201815-master
Finished: task service with 0 failures in 1.9 sec
INFO: Extending certificate on master pe-201815-master
Starting: task ca_regen::extend_ca_cert on pe-201815-master
Finished: task ca_regen::extend_ca_cert with 0 failures in 3.63 sec
INFO: Configuring master pe-201815-master to use new certificate
Starting: task ca_regen::configure_master on pe-201815-master
Finished: task ca_regen::configure_master with 0 failures in 97.6 sec
INFO: Configuring compile master(s) pe-201815-compile to use new certificate
Starting: file upload from /tmp/tmp.PLCWDd3RnL to /etc/puppetlabs/puppet/ssl/certs/ca.pem on pe-201815-compile
Finished: file upload from /tmp/tmp.PLCWDd3RnL to /etc/puppetlabs/puppet/ssl/certs/ca.pem with 0 failures in 0.62 sec
Starting: task run_agent on pe-201815-compile
Finished: task run_agent with 0 failures in 52.39 sec
INFO: CA cert decoded and stored at /tmp/tmp.PLCWDd3RnL
INFO: Run plan 'ca_regen::upload_ca_cert' to distribute to agents
Finished: plan ca_regen::ca_regen in 157.17 sec
Plan completed successfully with no result

$ bolt plan run ca_regen::upload_ca_cert agents=pe-201815-agent cert=/tmp/tmp.PLCWDd3RnL --run-as root
Starting: plan ca_regen::upload_ca_cert
Starting: plan ca_regen::get_agent_facts
Starting: install puppet and gather facts on pe-201815-agent
Finished: install puppet and gather facts with 0 failures in 8.9 sec
pe-201815-agent
Finished: plan ca_regen::get_agent_facts in 8.9 sec
Starting: plan facts
Starting: task facts on pe-201815-agent
Finished: task facts with 0 failures in 6.95 sec
Finished: plan facts in 6.97 sec
Starting: file upload from /tmp/tmp.PLCWDd3RnL to /etc/puppetlabs/puppet/ssl/certs/ca.pem on pe-201815-agent
Finished: file upload from /tmp/tmp.PLCWDd3RnL to /etc/puppetlabs/puppet/ssl/certs/ca.pem with 0 failures in 0.64 sec
Finished: plan ca_regen::upload_ca_cert in 16.54 sec
{
  "success": {
    "pe-201815-agent": {
      "_output": "Uploaded '/tmp/tmp.PLCWDd3RnL' to 'pe-201815-agent:/etc/puppetlabs/puppet/ssl/certs/ca.pem'"
    }
  }
}
```
