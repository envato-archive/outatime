require "spec_helper"

describe Outatime::CLI do
  let(:params) { { foo: 1, bar: "A" } }

  subject { described_class.new(params) }

  describe "#initialize" do
    it "sets the options" do
      expect(subject.options).to eq(params)
    end
  end

  describe "#run" do
    let(:fetcher) { double(Outatime::Fetcher) }
    it "runs the fetcher" do
      expect(Outatime::Fetcher).to receive(:new).and_return(fetcher)
      allow(fetcher).to receive(:total_size).and_return(1000)
      expect(fetcher).to receive(:fetch!)
      subject.run
    end
  end
end
