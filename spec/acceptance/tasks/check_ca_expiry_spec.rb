require 'spec_helper_acceptance'

describe 'check_ca_expiry task' do
  it 'returns valid by default' do
    result = run_bolt_task('ca_extend::check_ca_expiry')
    expect(result.stdout).to contain(%r{valid})
  end
end
