# frozen_string_literal: true

require "aws-sdk-s3"
require "chronic"
require "pathname"
require "ruby-progressbar"
require "thread"
require "trollop"
require_relative "outatime/version"
require_relative "outatime/fetcher"
require_relative "outatime/cli"

module Outatime
  # Public: Update AWS profile
  #
  # params - Hash of profile settings.
  #
  # Returns nothing.
  def self.update_aws_profile(params)
    Aws.config.update(params)
  end
end
