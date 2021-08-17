# @summary
#   A plan to work around BOLT-1168 so that one agent failing in apply_prep won't cause the whole plan to fail.
# @param nodes The targets to run apply_prep on
plan ca_extend::get_agent_facts(TargetSpec $nodes) {
  $nodes.apply_prep
}
