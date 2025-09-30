# frozen_string_literal: true

class FlagFraudIfSuspendedStripeFingerprintWorker
  include Sidekiq::Job
  sidekiq_options retry: 0, queue: :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if !user.can_flag_for_fraud?

    bank_account = user.active_bank_account
    return if bank_account.blank? || bank_account.stripe_fingerprint.blank?

    suspended_accounts_with_same_fingerprint = User.joins(:bank_accounts)
                                                .where(bank_accounts: { stripe_fingerprint: bank_account.stripe_fingerprint })
                                                .where(user_risk_state: ["suspended_for_tos_violation", "suspended_for_fraud"])

    user.flag_for_fraud!(author_name: "FlagFraudIfSuspendedStripeFingerprint") if suspended_accounts_with_same_fingerprint.exists?
  end
end
