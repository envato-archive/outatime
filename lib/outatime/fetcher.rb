module Outatime
  class Fetcher
    attr_accessor :options

    # Public: Fetcher will fetch the correct version of a file from S3.
    #
    # options - The Hash options used to configure how fetcher works:
    #           :bucket      - The versioned bucket name (required).
    #           :destination - Destination for restored files (required).
    #           :from        - Time description (required).
    #           :prefix      - Restore files from this prefix.
    #           :s3_client   - An existing Aws::S3::Client.
    #           :threads     - Number of download threads
    #           :verbose     - Verbose Mode
    #
    def initialize(options = {})
      @options           = options
      @files_mutex       = Mutex.new
      @fetch_block_mutex = Mutex.new
      @s3_client         = options[:s3_client] if options[:s3_client]
      @from = ::Chronic.parse(@options[:from]) if @options[:from]

      # raise if the date/time was not parsed
      raise ArgumentError, "The from time was not parseable." if @from.nil?
    end

    # Public: Fetches the file versions from S3 bucket.
    #
    # block - an optional block that receives the file description after it is
    # downloaded to the local.
    #
    # Returns nothing.
    def fetch!(&block)
      fetch_objects(object_versions, &block)
    end

    # Public: Returns the objects total size.
    #
    # Returns an integer.
    def total_size
      object_versions.inject(0) { |sum, obj| sum += obj.size }
    end

    # Public: Fetch the S3 object versions.
    #
    # Returns an Array of Aws::S3::Types::ObjectVersion.
    def object_versions
      puts "fetching object versions from #{@from}" if verbose?
      @files ||= begin
        versions = []
        delete_markers = []

        s3_client.list_object_versions(bucket: @options[:bucket],
          prefix: @options[:prefix]).each do |response|

          versions       += filter_future_items(response.versions, @from)
          delete_markers += filter_future_items(response.delete_markers, @from)
        end

        # keep only the latest versions
        # AWS lists the latest versions first, so it should be OK to use uniq here.
        versions.uniq!       { |obj| obj.key }
        delete_markers.uniq! { |obj| obj.key }

        delete_marker_keys = delete_markers.map { |dm| dm.key }

        # check versions to see if we have newer delete_markers
        # if so, delete those versions
        versions.delete_if do |version|
          if dm_index = delete_marker_keys.index(version.key)
            if version.last_modified <= delete_markers[dm_index].last_modified
              true
            end
          end
        end
      end
    end

    private

    # Private: Checks if it is in verbose mode.
    #
    # Returns a boolean.
    def verbose?
      @options[:verbose]
    end

    # Private: Fetches the objects from S3 bucket.
    #
    # files - an Array of Aws::S3::Types::ObjectVersion.
    #
    # Returns nothing.
    def fetch_objects(files)
      threads = []

      @options[:threads].times do
        threads << Thread.new do
          while !(file = @files_mutex.synchronize { files.pop }).nil? do
            dest = Pathname.new("#{@options[:destination]}/#{file.key}")

            if file.key.end_with?("/")
              puts "Creating s3 subdirectory #{file.key} - #{Time.now}" if verbose?
              dest.mkpath
            else
              dest.dirname.mkpath

              puts "Copying from s3 #{file.key} - #{Time.now}" if verbose?
              s3_client.get_object(response_target: "#{dest}",
                            bucket: @options[:bucket],
                            key: file.key,
                            version_id: file.version_id)
            end

            @fetch_block_mutex.synchronize { yield file } if block_given?
          end
        end
      end

      threads.map(&:join)
    end

    # Private: Creates the S3 client instance.
    #
    # Returns an Aws::S3::Client.
    def s3_client
      region = @options[:region] || ENV["AWS_REGION"]
      @s3_client ||= Aws::S3::Client.new(region: region)
    end

    # Private: Returns an Array of items modified on or before the given date/time.
    #
    # items - An Array of objects. Object must respond to #last_modified.
    # date_time - Comparison date/time.
    #
    # Returns Array.
    def filter_future_items(items, date_time)
      items.find_all do |obj|
        obj.last_modified <= @from
      end
    end
  end
end
