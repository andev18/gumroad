# frozen_string_literal: true

describe FlagFraudIfSuspendedStripeFingerprintWorker do
  before do
    @stripe_fingerprint = "test_stripe_fingerprint"
    @suspended_user = create(:user, user_risk_state: :suspended_for_fraud)
    create(:ach_account, user: @suspended_user, stripe_fingerprint: @stripe_fingerprint)
  end

  it "does not flag the user for fraud if there are no other suspended users with the same Stripe fingerprint" do
    @user = create(:user)
    create(:ach_account, user: @user, stripe_fingerprint: "different_fingerprint")

    described_class.new.perform(@user.id)

    expect(@user.reload.flagged_for_fraud?).to be(false)
  end

  it "flags the user for fraud if there are other suspended users with the same Stripe fingerprint" do
    @user = create(:user)

    create(:ach_account, user: @user, stripe_fingerprint: @stripe_fingerprint)

    described_class.new.perform(@user.id)

    expect(@user.reload.flagged_for_fraud?).to be(true)
  end
end
