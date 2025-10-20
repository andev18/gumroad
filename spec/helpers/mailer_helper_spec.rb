# frozen_string_literal: true

require "spec_helper"

describe MailerHelper do
  describe "#from_email_address_name" do
    context "when name contains colon character" do
      it "returns 'Gumroad' for name with colon" do
        expect(from_email_address_name("John: The Creator")).to eq("Gumroad")
      end
    end
  end
end
