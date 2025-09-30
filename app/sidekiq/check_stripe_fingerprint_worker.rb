# frozen_string_literal: true

class CheckStripeFingerprintWorker
  include Sidekiq::Job
  sidekiq_options retry: 0, queue: :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if !user.can_flag_for_fraud?

    active_bank_account = user.active_bank_account
    return if active_bank_account.blank? || active_bank_account.stripe_fingerprint.blank?

    stripe_fingerprint = active_bank_account.stripe_fingerprint

    # Find other users with bank accounts that have the same stripe fingerprint and are suspended
    banned_accounts_with_same_fingerprint = User.joins(:bank_accounts)
                                                .where(bank_accounts: { stripe_fingerprint: stripe_fingerprint })
                                                .where(user_risk_state: ["suspended_for_tos_violation", "suspended_for_fraud"])
                                                .where.not(id: user.id)

    user.flag_for_fraud!(author_name: "CheckStripeFingerprint") if banned_accounts_with_same_fingerprint.exists?
  end
end
