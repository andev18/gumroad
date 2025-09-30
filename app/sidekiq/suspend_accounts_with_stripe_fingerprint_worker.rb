# frozen_string_literal: true

class SuspendAccountsWithStripeFingerprintWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :default

  def perform(user_id)
    suspended_user = User.find(user_id)

    return if suspended_user.active_bank_account.blank? || suspended_user.active_bank_account.stripe_fingerprint.blank?

    stripe_fingerprint = suspended_user.active_bank_account.stripe_fingerprint

    bank_accounts_with_same_fingerprint = BankAccount.alive
                                       .where(stripe_fingerprint: stripe_fingerprint)
                                       .where.not(user_id: suspended_user.id)
                                       .includes(:user)

    bank_accounts_with_same_fingerprint.find_each do |bank_account|
      user.flag_for_fraud(
        author_name: "suspend_sellers_other_accounts",
        content: "Flagged for fraud automatically on #{Time.current.to_fs(:formatted_date_full_month)} because of usage of ACH bank account with Stripe fingerprint #{stripe_fingerprint} (from User##{suspended_user.id})"
      )
      user.suspend_for_fraud(
        author_name: "suspend_sellers_other_accounts",
        content: "Suspended for fraud automatically on #{Time.current.to_fs(:formatted_date_full_month)} because of usage of ACH bank account with Stripe fingerprint #{stripe_fingerprint} (from User##{suspended_user.id})"
      )
    end
  end
end
