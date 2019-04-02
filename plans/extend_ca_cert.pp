plan ca_extend::extend_ca_cert(TargetSpec $master, Optional[TargetSpec] $compile_masters = undef) {
  $b64_test = run_command('echo "test" | base64 -w 0 - &>/dev/null', 'localhost', '_catch_errors' => true)
  unless $b64_test.ok {
    fail_plan('This utility requires a version of base64 with the -w flag')
  }

  notice("INFO: Stopping puppet and pe-puppetserver services on $master")
  run_task('service', $master, 'action' => 'stop', 'name' => 'puppet')
  run_task('service', $master, 'action' => 'stop', 'name' => 'pe-puppetserver')

  notice("INFO: Extending certificate on master $master")
  $regen_results =  run_task('ca_extend::extend_ca_cert', $master)
  $new_cert = $regen_results.first.value
  $cert_contents = $new_cert['contents']

  notice("INFO: Configuring master $master to use new certificate")
  run_task('ca_extend::configure_master', $master, 'new_cert' => $new_cert['new_cert'])
  run_task('service', $master, 'action' => 'start', 'name' => 'puppet')

  # Suppress the base64 encoded cert from going to stdout
  $decode = without_default_logging() || {
    run_command("tmp=$(mktemp) && echo $cert_contents | base64 -d - >\$tmp && echo -n \$tmp", 'localhost', '_catch_errors' => true)
  }

  unless $decode.ok {
    fail_plan('encoding error', 'command-unexpected-result', { 'stderr' => $decode.first.value['_error']['msg'] })
  }

  if $compile_masters {
    notice("INFO: Configuring compile master(s) $compile_masters to use new certificate")
    upload_file("${decode.first.value['stdout']}", '/etc/puppetlabs/puppet/ssl/certs/ca.pem', $compile_masters)

    # Just running Puppet with the new cert in place should be enough
    run_task('run_agent', $compile_masters)
  }


  notice("INFO: CA cert decoded and stored at ${decode.first.value['stdout']}")
  notice("INFO: Run plan 'ca_extend::upload_ca_cert' to distribute to agents")

}
