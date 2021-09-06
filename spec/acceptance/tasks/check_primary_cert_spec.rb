require 'spec_helper_acceptance'

describe 'check_primary_cert task' do
  it 'returns success' do
    result = run_bolt_task('ca_extend::check_primary_cert')
    expect(result.stdout).to contain(%r{success})
  end
end
