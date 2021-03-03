plan ca_extend::extend_ca_cert(
  TargetSpec $targets,
  Optional[TargetSpec] $compile_masters = undef,
  $ssldir                               = '/etc/puppetlabs/puppet/ssl',
  $regen_primary_cert                   = false,
) {
  $targets.apply_prep
  $master_facts = run_task('facts', $targets, '_catch_errors' => true).first

  if $master_facts['pe_build'] {
    $is_pe = true
    $services = ['puppet', 'pe-puppetserver', 'pe-postgresql']
  }
  elsif $master_facts['puppetversion'] {
    $is_pe = false
    $services = ['puppet', 'puppetserver']
  }
  else {
    fail_plan("Puppet not detected on ${targets}")
  }

  if $is_pe and ! $regen_primary_cert{
    $out = run_task('ca_extend::check_primary_cert', $targets, '_catch_errors' => true).first
    unless $out.ok {
      fail_plan($out.value['message'])
    }
    if $out.value['status'] == 'warn' {
      warning($out.value['message'])
    }
  }

  out::message("INFO: Stopping Puppet services on ${targets}")
  $services.each |$service| {
    run_task('service::linux', $targets, 'action' => 'stop', 'name' => $service)
  }

  out::message("INFO: Extending CA certificate on ${targets}")
  $regen_results = run_task('ca_extend::extend_ca_cert', $targets)
  $new_cert = $regen_results.first.value
  $cert_contents = base64('decode', $new_cert['contents'])

  out::message("INFO: Configuring ${targets} to use the extended CA certificate")
  if $is_pe {
    run_task('ca_extend::configure_master', $targets,
      'new_cert' => $new_cert['new_cert'], 'regen_primary_cert' => $regen_primary_cert
    )
  }
  else {
    run_command("/bin/cp ${new_cert['new_cert']} ${ssldir}/certs/ca.pem", $targets)
    run_command("/bin/cp ${new_cert['new_cert']} ${ssldir}/ca/ca_crt.pem", $targets)
    run_task('service::linux', $targets, 'action' => 'start', 'name' => 'puppetserver')
  }
  run_task('service::linux', $targets, 'action' => 'start', 'name' => 'puppet')

  $tmp = run_command('mktemp', 'localhost', '_run_as' => system::env('USER'))
  $tmp_file = $tmp.first.value['stdout'].chomp
  file::write($tmp_file, $cert_contents)

  if $compile_masters {
    out::message("INFO: Stopping Puppet services on compilers (${compile_masters})")
    run_task('service::linux', $compile_masters, 'action' => 'stop', 'name' => 'puppet')

    out::message("INFO: Configuring compilers (${compile_masters}) to use the extended CA certificate")
    upload_file($tmp_file, '/etc/puppetlabs/puppet/ssl/certs/ca.pem', $compile_masters)

    # Just running Puppet with the new CA certificate in place should be enough.
    run_command('/opt/puppetlabs/bin/puppet agent --no-daemonize --no-noop --onetime', $compile_masters)
    run_task('service::linux', $compile_masters, 'action' => 'start', 'name' => 'puppet')
  }

  out::message("INFO: Extended CA certificate decoded and stored at ${tmp_file}")
  out::message("INFO: Run the 'ca_extend::upload_ca_cert' plan to distribute the extended CA certificate to agents")
}
