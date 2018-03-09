# frozen_string_literal: true

module Outatime
  class CLI
    attr_accessor :options

    # Public: It will fetch the correct version of a file from S3 and shows a
    # progress bar to indicate its progress.
    #
    # options - The Hash options used to configure how fetcher works:
    #           :region      - The AWS region.
    #           :bucket      - The versioned bucket name.
    #           :from        - Time description.
    #           :prefix      - Restore files from this prefix.
    #           :destination - Destination for restored files
    #           :threads     - Number of download threads
    #           :verbose     - Verbose Mode
    #
    def initialize(options)
      @options = options
    end

    # Public: Runs the fetcher and download the correct files version.
    def run
      fetcher = Outatime::Fetcher.new(options)

      pb = ProgressBar.create(total: nil,
                              format: "%t: |%B| %f %c/%C %R MB/sec",
                              rate_scale: lambda { |rate| rate / 1024 / 1024 },
                              throttle_rate: 0.5)

      fetcher.fetch! do |file|
        pb.progress += file.size
      end
    end
  end
end
