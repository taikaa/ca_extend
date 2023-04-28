# frozen_string_literal: true

require 'singleton'
require 'serverspec'
require 'puppetlabs_spec_helper/module_spec_helper'

class LitmusHelper
  include Singleton
  include PuppetLitmus
end
