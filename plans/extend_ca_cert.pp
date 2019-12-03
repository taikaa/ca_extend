plan ca_extend::extend_ca_cert(
  TargetSpec $master,
  Optional[TargetSpec] $compile_masters = undef,
  $ssldir = '/etc/puppetlabs/puppet/ssl',
) {
  $master.apply_prep
  $master_facts = run_plan('facts', $master).first

  if ! empty("${master_facts['pe_build']}") {
    $services = ['puppet', 'pe-puppetserver', 'pe-postgresql']
    $is_pe = true
  }
  elsif "${master_facts['puppetversion']}" {
    $is_pe = false
    $services = ['puppet', 'puppetserver']
  }
  else {
    fail_plan('Puppet installation not detected')
  }

  out::message("INFO: Stopping $services services on ${master}")
  $services.each |$s| {
    run_task('service::linux', $master, 'action' => 'stop', 'name' => $s)
  }

  out::message("INFO: Extending certificate on master ${master}")
  $regen_results =  run_task('ca_extend::extend_ca_cert', $master)
  $new_cert = $regen_results.first.value
  $cert_contents = base64('decode', $new_cert['contents'])

  out::message("INFO: Configuring master ${master} to use new certificate")
  if $is_pe {
    run_task('ca_extend::configure_master', $master, 'new_cert' => $new_cert['new_cert'])
  }
  else {
    run_command("/bin/cp ${new_cert['new_cert']} $ssldir/certs/ca.pem", $master)
    run_command("/bin/cp ${new_cert['new_cert']} $ssldir/ca/ca_crt.pem", $master)
    run_task('service::linux', $master, 'action' => 'start', 'name' => 'puppetserver')
  }
  run_task('service::linux', $master, 'action' => 'start', 'name' => 'puppet')

  $tmp = run_command('mktemp', 'localhost', '_run_as' => system::env('USER'))
  $tmp_file = $tmp.first.value['stdout'].chomp
  file::write($tmp_file, $cert_contents)

  if $compile_masters {
    out::message("INFO: Stopping puppet service on ${compile_masters}")

    run_task('service::linux', $compile_masters, 'action' => 'stop', 'name' => 'puppet')
    out::message("INFO: Configuring compile master(s) ${compile_masters} to use new certificate")
    upload_file($tmp_file, '/etc/puppetlabs/puppet/ssl/certs/ca.pem', $compile_masters)

    # Just running Puppet with the new cert in place should be enough
    run_command('/opt/puppetlabs/bin/puppet agent --no-daemonize --no-noop --onetime', $compile_masters)
    run_task('service::linux', $compile_masters, 'action' => 'start', 'name' => 'puppet')
  }

  out::message("INFO: CA cert decoded and stored at ${tmp_file}")
  out::message("INFO: Run plan 'ca_extend::upload_ca_cert' to distribute to agents")
}
