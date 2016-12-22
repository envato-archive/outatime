$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "outatime"

Aws.config[:stub_responses] = true
