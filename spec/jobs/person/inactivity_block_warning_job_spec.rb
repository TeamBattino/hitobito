# encoding: utf-8

#  Copyright (c) 2023, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require 'spec_helper'

describe Person::InactivityBlockWarningJob do
  subject(:job) { described_class.new }
  let!(:person) { people(:bottom_member) }
  let(:warn_after_value) { 6.months }
  let(:last_sign_in_at) { warn_after_value&.+(3.months)&.ago }

  describe '#perform' do
    before do
      allow(Person::BlockService).to receive(:block_after).and_return(block_after_value)
      expect(Person::BlockService).to receive(:block_within_scope).and_call_original
    end

    context "with no block_after set" do
      let(:block_after_value) { nil }
      it { expect(job.perform).to be_falsy }
    end

    context "with no block_after set" do
      it { expect(job.perform).to be_truthy }
    end
  end
end
