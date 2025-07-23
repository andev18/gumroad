# frozen_string_literal: true

require "spec_helper"
require "uri"

describe "Upsell discount code re-application", :js, type: :feature do
  let(:seller) { create(:named_seller, display_offer_code_field: true) }
  let(:product_a) { create(:product, name: "Product A", user: seller, price_cents: 5000) } # $50
  let(:bundle_b) { create(:product, name: "Bundle B", user: seller, price_cents: 15000) } # $150
  let(:discount_code) { create(:percentage_offer_code, code: "SAVE50", amount_percentage: 50, user: seller, products: [product_a, bundle_b]) }

  before do
    create(:upsell,
      text: "Upgrade to Bundle B",
      description: "Get the complete bundle for more value!",
      seller: seller,
      product: bundle_b,
      selected_products: [product_a],
      cross_sell: true,
      replace_selected_products: true
    )
  end

  describe "discount code re-application during upsell acceptance" do
    it "applies discount to upsell product when accepting upsell" do
      visit "/l/#{product_a.unique_permalink}?offer_code=#{discount_code.code}"

      expect(page).to have_selector("[role='status']", text: "50% off will be applied at checkout (Code SAVE50)")

      within find(:article) do
        buy_button = find(:link, "I want this!")
        uri = URI.parse buy_button[:href]
        expect(uri.path).to eq "/checkout"
        query = Rack::Utils.parse_query(uri.query)
        expect(query["product"]).to eq(product_a.unique_permalink)
        expect(query["code"]).to eq(discount_code.code)
        buy_button.click
      end

      expect(page).to have_text("Checkout")
      expect(page).to have_text("Product A")

      expect(page).to have_selector("[aria-label='Discount code']", text: discount_code.code)
      expect(page).to have_text("Total US$25", normalize_ws: true)

      fill_checkout_form(product_a)
      click_on "Pay"

      within_modal "Upgrade to Bundle B" do
        expect(page).to have_text("Get the complete bundle for more value!")
        expect(page).to have_text("Bundle B")
        click_on "Upgrade"
      end

      expect(page).to have_alert(text: "Your purchase was successful! We sent a receipt to test@gumroad.com.")

      purchase = Purchase.last
      expect(purchase.link).to eq(bundle_b)
      expect(purchase.offer_code).to eq(discount_code)
      expect(purchase.price_cents).to eq(7500)
      expect(purchase.variant_attributes.first).to eq(bundle_b.alive_variants.first)
    end

    it "does not apply discount codes that don't apply to the upsell product" do
      product_a_only_discount = create(:percentage_offer_code, code: "AONLY", amount_percentage: 20, user: seller, products: [product_a])

      visit "/l/#{product_a.unique_permalink}"
      add_to_cart(product_a)

      fill_in "Discount code", with: product_a_only_discount.code
      click_on "Apply"

      expect(page).to have_text("Total US$40", normalize_ws: true) # $50 - 20% = $40

      fill_checkout_form(product_a)
      click_on "Pay"

      within_modal "Upgrade to Bundle B" do
        click_on "Upgrade"
      end

      expect(page).not_to have_selector("[aria-label='Discount code']", text: product_a_only_discount.code)
      expect(page).to have_text("Total US$150", normalize_ws: true)
    end
  end
end
