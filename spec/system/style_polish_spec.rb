require "rails_helper"

# Links without underlines, inputs without focus outlines, and roomier home cards.
RSpec.describe "Style polish", type: :system do
  def computed(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).getPropertyValue(#{property.to_json})")
  end

  on_each_viewport do
    it "shows links bold and without an underline" do
      visit new_session_path

      link = ".auth-card__switch a"
      expect(computed(link, "text-decoration-line")).to eq("none")
      expect(computed(link, "font-weight").to_i).to be >= 600
    end

    it "marks a focused input with its border, not an outline" do
      visit new_session_path
      find_field("email_address").click

      expect(computed("#email_address", "outline-style")).to eq("none")
      # The border colour eases in over --motion-fast, so wait for it to settle.
      expect { computed("#email_address", "border-top-color") }.to eventually(eq("rgb(88, 101, 242)")) # --color-primary
    end

    it "gives home book cards more room" do
      create_list(:book, 6, :published)
      sign_in_and_wait_as(create(:user))

      columns = computed("#recent_books", "grid-template-columns").split.size
      card_width = page.evaluate_script("document.querySelector('#recent_books .book-card').getBoundingClientRect().width")

      if mobile_viewport?
        expect(columns).to eq(2)
        expect(card_width).to be >= 150
      else
        expect(card_width).to be >= 200
      end
    end
  end
end
