# This plan is to work around BOLT-1168 so that one agent failing in
# apply_prep won't cause the whole plan to fail
plan ca_regen::get_agent_facts(TargetSpec $agents) {
  $agents.apply_prep
}
