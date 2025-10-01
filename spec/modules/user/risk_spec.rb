# frozen_string_literal: true

require "spec_helper"

describe User::Risk do
  describe "#disable_refunds!" do
    before do
      @creator = create(:user)
    end

    it "disables refunds for the creator" do
      @creator.disable_refunds!
      expect(@creator.reload.refunds_disabled?).to eq(true)
    end
  end

  describe "#log_suspension_time_to_mongo", :sidekiq_inline do
    let(:user) { create(:user) }
    let(:collection) { MONGO_DATABASE[MongoCollections::USER_SUSPENSION_TIME] }

    it "writes suspension data to mongo collection" do
      freeze_time do
        user.log_suspension_time_to_mongo

        record = collection.find("user_id" => user.id).first
        expect(record).to be_present
        expect(record["user_id"]).to eq(user.id)
        expect(record["suspended_at"]).to eq(Time.current.to_s)
      end
    end
  end

  describe ".refund_queue", :sidekiq_inline do
    it "returns users suspended for fraud with positive unpaid balances" do
      user = create(:user)
      create(:balance, user: user, amount_cents: 5000, state: "unpaid")
      user.flag_for_fraud!(author_name: "admin")
      user.suspend_for_fraud!(author_name: "admin")

      result = User.refund_queue

      expect(result.to_a).to eq([user])
    end
  end

  describe "#suspend_sellers_other_accounts" do
    let(:user) { create(:user) }

    it "enqueues both PayPal and Stripe fingerprint account suspension workers" do
      expect(SuspendAccountsWithPaymentAddressWorker).to receive(:perform_in).with(5.seconds, user.id)
      expect(SuspendAccountsWithStripeFingerprintWorker).to receive(:perform_in).with(5.seconds, user.id)

      user.suspend_sellers_other_accounts
    end
  end

  describe "#enable_sellers_other_accounts" do
    before do
      @stripe_fingerprint = "test_stripe_fingerprint"
      @user = create(:user)
      @user_2 = create(:user, user_risk_state: :suspended_for_fraud)

      create(:ach_account, user: @user, stripe_fingerprint: @stripe_fingerprint)
      create(:ach_account, user: @user_2, stripe_fingerprint: @stripe_fingerprint)
    end

    it "marks other accounts with the same Stripe fingerprint as compliant" do
      @user.enable_sellers_other_accounts

      expect(@user_2.reload.compliant?).to be(true)
      expect(@user_2.comments.last.content).to eq("Marked compliant automatically on #{Time.current.to_fs(:formatted_date_full_month)} as ACH bank account with Stripe fingerprint #{@stripe_fingerprint} is now unblocked")
      expect(@user_2.comments.last.author_name).to eq("enable_sellers_other_accounts")
    end
  end
end
