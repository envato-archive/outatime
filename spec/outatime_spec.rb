require "spec_helper"

describe Outatime do
  it "has a version number" do
    expect(Outatime::VERSION).not_to be nil
  end

  describe "::update_aws_profile" do
    let(:params) { { foo: 1, bar: "A" } }

    it "updates the AWS profile" do
      expect(Aws.config).to receive(:update).with(params)
      described_class.update_aws_profile(params)
    end
  end
end
