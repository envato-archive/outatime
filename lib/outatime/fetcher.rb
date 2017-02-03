require 'thread/pool'

# Outatime::Fetcher is responsible for finding the exact revision for each file
# for a given time.
#
# AWS S3 API lists all file revisions in a very particular order and this
# class takes advantage of that to quickly parse and find the revision.
#
# The 'GET Bucket Object Versions'
# (http://docs.aws.amazon.com/AmazonS3/latest/API/RESTBucketGETVersion.html)
# returns all file revisions ordered by key (path + filename) and last
# modified time.
#
# For example:
#
# id: 12456, key: "src/file1", last_modified: 7 Feb 11:38
# id: 12357, key: "src/file1", last_modified: 7 Feb 11:37
# id: 12357, key: "src/file1", last_modified: 7 Feb 11:00
# id: 22222, key: "src/file2", last_modified: 7 Feb 11:39
# ...
#
# Keep in mind that this response is paginated, where the max amount of
# revisions per page is 1000.
#
# When a versioned bucket contains a huge amount of files and revisions,
# fetching all data may take a long time. So Outatime::Fetcher starts
# downloading the correct revision even when not all file revisions are
# already fetched, i.e. when it is still downloading the revisions and their
# data. That accelerates the process.
#
# So how do we know when we have all information we need before start downloading
# a specific file revision? As the response is ordered by key (filename) and
# timestamps, fetcher can start downloading if the actual response page
# contains all possible revisions for a file, i.e. its revisions aren't
# paginated.
#
# When the response for a given key (filename) is paginated, the file is not
# downloaded until all revisions are fetched in the next response page.
#
# This algorithm removes the need to fetch all file revisions (which may take
# several requests) for a versioned bucket before starting to download its files,
# but acts on each individual file instead.
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
      @fetch_block_mutex = Mutex.new
      @s3_client         = options[:s3_client] if options[:s3_client]
      @from              = ::Chronic.parse(@options[:from]) if @options[:from]
      @pool              = Thread.pool(@options.fetch(:threads, 20))

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
      object_versions do |object_version|
        fetch_object(object_version, &block)
      end

      @pool.wait(:done)
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
      remaining_versions       = []
      remaining_delete_markers = []

      s3_client.list_object_versions(bucket: @options[:bucket],
        prefix: @options[:prefix]).each do |response|

        versions              = remaining_versions.concat(response.versions)
        versions_by_key       = versions.group_by {|v| v.key }
        delete_markers        = remaining_delete_markers.concat(response.delete_markers)
        delete_markers_by_key = delete_markers.group_by {|v| v.key }

        versions_by_key.each do |key, versions|
          next if response.next_key_marker == key
          filter_items(versions).each do |version|
            dl_marker = filter_items(Array(delete_markers_by_key[version.key])).first
            if dl_marker.nil? || (version.last_modified > dl_marker.last_modified)
              yield version
            end
          end
        end

        remaining_versions       = Array(versions_by_key[response.next_key_marker])
        remaining_delete_markers = Array(delete_markers_by_key[response.next_key_marker])
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
    def fetch_object(file)
      @pool.process do
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

    # Private: Creates the S3 client instance.
    #
    # Returns an Aws::S3::Client.
    def s3_client
      region = @options[:region] || ENV["AWS_REGION"]
      @s3_client ||= Aws::S3::Client.new(region: region)
    end

    # Private: Returns an Array of items modified on or before the @from date/time.
    #
    # items - An Array of objects. Object must respond to #last_modified.
    #
    # Returns Array.
    def filter_items(items)
      items.keep_if { |obj| obj.last_modified <= @from }.uniq {|obj| obj.key }
    end
  end
end
