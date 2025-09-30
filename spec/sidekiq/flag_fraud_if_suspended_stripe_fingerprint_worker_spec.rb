# frozen_string_literal: true

describe FlagFraudIfSuspendedStripeFingerprintWorker do
  describe "#perform" do
    before do
      @stripe_fingerprint = "fp_test_fingerprint_123"
      @user = create(:user)
      @suspended_user = create(:user, user_risk_state: :suspended_for_fraud)
      create(:user) # admin user

      create(:ach_account, user: @user, stripe_fingerprint: @stripe_fingerprint)
      create(:ach_account, user: @suspended_user, stripe_fingerprint: @stripe_fingerprint)
    end

    it "flags user if they have the same stripe fingerprint as a suspended account" do
      expect(@user.flagged_for_fraud?).to be(false)

      described_class.new.perform(@user.id)

      expect(@user.reload.flagged_for_fraud?).to be(true)
      expect(@user.comments.last.content).to include("Flagged for fraud by FlagFraudIfSuspendedStripeFingerprint")
      expect(@user.comments.last.author_name).to eq("FlagFraudIfSuspendedStripeFingerprint")
    end

    it "does not flag user if no suspended accounts share the same fingerprint" do
      @suspended_user.bank_accounts.update_all(stripe_fingerprint: "different_fingerprint")

      described_class.new.perform(@user.id)

      expect(@user.reload.flagged_for_fraud?).to be(false)
    end

    it "handles users without active bank accounts gracefully" do
      user_without_bank = create(:user)

      expect do
        described_class.new.perform(user_without_bank.id)
      end.not_to raise_error
    end

    it "handles users with bank accounts without stripe fingerprints gracefully" do
      user_with_blank_fingerprint = create(:user)
      create(:ach_account, user: user_with_blank_fingerprint, stripe_fingerprint: nil)

      expect do
        described_class.new.perform(user_with_blank_fingerprint.id)
      end.not_to raise_error
    end
  end
end
