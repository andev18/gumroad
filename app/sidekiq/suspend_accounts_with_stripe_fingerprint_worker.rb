# frozen_string_literal: true

class SuspendAccountsWithStripeFingerprintWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :default

  def perform(user_id)
    suspended_user = User.find(user_id)

    active_bank_account = suspended_user.active_bank_account
    return if active_bank_account.blank? || active_bank_account.stripe_fingerprint.blank?

    stripe_fingerprint = active_bank_account.stripe_fingerprint

    matching_bank_accounts = BankAccount.alive
                                       .where(stripe_fingerprint: stripe_fingerprint)
                                       .where.not(user_id: suspended_user.id)
                                       .includes(:user)

    matching_bank_accounts.find_each do |bank_account|
      user = bank_account.user
      next if user.blank? || user.suspended?

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
