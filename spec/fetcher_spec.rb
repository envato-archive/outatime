require "spec_helper"
require 'active_support/core_ext/time'
require 'yaml'

describe Outatime::Fetcher do
  let(:params) do
    {
      region: 'us-east-1',
      bucket: 'test-bucket',
      from: 'Nov 4 2016 15:00:00',
      prefix: '/',
      destination: 'downloaded_files',
      threads: 2,
    }
  end

  let(:s3_client) { Aws::S3::Client.new(stub_responses: true)}

  before do
    # Chronic normally uses the local time zone - force that time zone here so
    # the code returns the expected state of the bucket at the given time.
    Time.zone = "Eastern Time (US & Canada)"
    Chronic.time_class = Time.zone

    allow(subject).to receive(:s3_client).and_return(s3_client)
  end

  subject do
    described_class.new(params)
  end

  describe "#initialize" do
    it "sets the options" do
      expect(subject.options).to eq(params)
    end

    it "raises with an unparseable from value" do
      expect { described_class.new(params.merge(from: "BAD TIME")) }
        .to raise_error(ArgumentError)
    end
  end

  describe "#fetch!" do
    let(:files) do
      [
        double(Aws::S3::Types::ObjectVersion, key: "example.txt", version_id: "abc123", size: 100),
        double(Aws::S3::Types::ObjectVersion, key: "directory/",  version_id: "def456", size: 0)
      ]
    end

    let(:file_dest)      { double(Pathname) }
    let(:file_directory) { double(Pathname) }
    let(:directory_dest) { double(Pathname) }

    before do
      allow(Pathname).to receive(:new)
        .with("#{params[:destination]}/#{files[0].key}").and_return(file_dest)
      allow(Pathname).to receive(:new)
        .with("#{params[:destination]}/#{files[1].key}").and_return(directory_dest)
      allow(file_dest).to receive(:dirname).and_return(file_directory)

      allow(s3_client).to receive(:get_object).with(
        {
          response_target: file_dest.to_s,
          bucket: params[:bucket],
          key: files[0].key,
          version_id: files[0].version_id
        }
      )

      allow(subject).to receive(:object_versions).and_return(files)
    end

    it "downloads the files" do
      # it creates a directory for the file entry
      expect(file_directory).to receive(:mkpath)

      # it creates a directory entry
      expect(directory_dest).to receive(:mkpath)

      subject.fetch!
    end

    it "with a block" do
      allow(file_directory).to receive(:mkpath)
      allow(directory_dest).to receive(:mkpath)

      size = 0
      subject.fetch! { |file| size += file.size }
      expect(size).to eq(100)
    end
  end

  describe "#total_size" do
    it "computes the total size of the files" do
      expect(subject).to receive(:object_versions).and_return(
        [123, 456, 789].map { |size| double(Aws::S3::Types::ObjectVersion, size: size) }
      )

      expect(subject.total_size).to eq(1368)
    end
  end

  describe "#object_versions" do
    it "generates the proper object versions" do
      s3_client.stub_responses(:list_object_versions,
        versions: [
          {
            key: "future_file",
            last_modified: Chronic.parse("2016-11-05 14:49:00.000000000 Z"),
            version_id: "441"
          },
          {
            key: "deleted_file",
            last_modified: Chronic.parse("2016-10-26 14:49:00.000000000 Z"),
            version_id: "331"
          },
          {
            key: "index.html",
            last_modified: Chronic.parse("2016-10-26 14:48:30.000000000 Z"),
            version_id: "221"
          },
          {
            key: "deleted_directory/",
            last_modified: Chronic.parse("2016-10-26 14:48:00.000000000 Z"),
            version_id: "551"
          },
          {
            key: "README",
            last_modified: Chronic.parse("2016-10-26 14:48:00.000000000 Z"),
            version_id: "112"
          },
          {
            key: "README",
            last_modified: Chronic.parse("2016-10-26 14:47:00.000000000 Z"),
            version_id: "111"
          },
          {
            key: "lib/",
            last_modified: Chronic.parse("2016-10-26 14:46:00.000000000 Z"),
            version_id: "661"
          },
        ],
        delete_markers: [
          {
            key: "deleted_file",
            last_modified: Chronic.parse("2016-10-26 14:50:00.000000000 Z")
          },
          {
            key: "deleted_directory/",
            last_modified: Chronic.parse("2016-10-26 14:51:00.000000000 Z")
          },
          {
            key: "README",
            last_modified: Chronic.parse("2016-10-26 14:40:00.000000000 Z") # delete mark that happened before the last file modification, so it is ignored
          }
        ])

      versions = subject.object_versions

      # ensure we are returning S3 object versions
      expect(versions.map(&:class).uniq).to eq([Aws::S3::Types::ObjectVersion])

      # ensure we are not returning non-deleted files
      expect(versions.map(&:key)).to match_array(%w(README lib/ index.html))

      # ensure the correct file versions are returned
      expect(versions.map(&:version_id))
        .to match_array([
          "112", # README
          "221", # index.html
          "661", # lib/
        ])
    end
  end
end
