plan ca_regen::upload_ca_cert(TargetSpec $agents, String $cert) {
  $agents.apply_prep
  #TODO: filter *nix and windows nodes. Break into separate task for manual upload?
  $tmp = run_plan('facts', 'nodes' => $agents, '_catch_errors' => true)

  # Is there a better way to do success and failure?
  $ok = $tmp.filter |$n| { $n.ok }
  $not_ok = $tmp.filter |$n| { ! $n.ok }

  $windows_targets = $ok.filter |$n| { $n.value['os']['family'] == "windows" }
  $linux_targets = $ok - $windows_targets

  $windows_results = upload_file(
    $cert,
    'C:\ProgramData\PuppetLabs\puppet\etc\ssl\certs\ca.pem',
    $windows_targets.map |$item| { $item.target.name },
    '_catch_errors' => true
  )

  notice($windows_results)

  $linux_results = upload_file(
    $cert,
    '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
    $linux_targets.map |$item| { $item.target.name },
    '_catch_errors' => true
  )

  $good = deep_merge(
    { "success" => $windows_results.filter |$result| { $result.ok }.map |$result| {
        { $result.target.name => $result.value }
      }.reduce |$memo, $value| { $memo + $value }
    },
    { "success" => $linux_results.filter |$result| { $result.ok }.map |$result| {
        { $result.target.name => $result.value }
      }.reduce |$memo, $value| { $memo + $value }
    }
  )

  notice($good)

  $bad = deep_merge(
    { "failure" => $windows_results.filter |$result| { ! $result.ok }.map |$result| {
        { $result.target.name => $result.value }
      }.reduce |$memo, $value| { $memo + $value }
    },
    { "failure" => $linux_results.filter |$result| { ! $result.ok }.map |$result| {
        { $result.target.name => $result.value }
      }.reduce |$memo, $value| { $memo + $value }
    }
  )

  notice($bad)

  return deep_merge($good, $bad)

}

