# This plan is to work around BOLT-1168,
# so that one agent failing in apply_prep won't cause the whole plan to fail.

plan ca_extend::get_agent_facts(TargetSpec $nodes) {
  $nodes.apply_prep
}
