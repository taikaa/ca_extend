#TODO: copy to compile masters
plan ca_regen::ca_regen(TargetSpec $master, TargetSpec $agents) {
  #TODO: test base64 locally
  notice("Stopping puppet and pe-puppetserver services on $master")
  run_task('service', $master, 'action'                                                                                    => 'stop', 'name' => 'puppet')
  run_task('service', $master, 'action'                                                                                    => 'stop', 'name' => 'pe-puppetserver')

  $regen_results =  run_task('ca_regen::extend_ca_cert', $master)
  $new_cert = $regen_results.first.value
  $cert_contents = $new_cert['contents']

  run_task('ca_regen::copy_master_ca', $master, 'new_cert'                                                                 => $new_cert['new_cert'])

  $decode = without_default_logging() || {
    run_command("tmp=$(mktemp) && echo $cert_contents | base64 -d - >\$tmp && echo -n \$tmp", 'localhost', '_catch_errors' => true, '_without_default_logging' => true)
  }

  unless $decode.ok {
    fail_plan('encoding error', 'command-unexpected-result', { 'stderr'                                                    => $decode.first.value['_error']['msg'] })
  }

  notice($decode)

  return run_plan('ca_regen::upload_ca_cert', 'agents'                                                                        => $agents, 'cert' => '/tmp/foo')

  #  $good = { "failure"                                                                                                      => $linux_results.filter |$result| { ! $result.ok }.map |$result| {
  #      { $result.target.name                                                                                                => $result.value }
  #    }.reduce |$memo, $value| { $memo + $value }
  #  }

}
