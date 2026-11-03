require "rails_helper"

RSpec.describe "Reader: never losing a position", type: :system do
  on_each_viewport do
    let(:reader) { create(:user) }
    let(:book) { create(:book, :published, file_fixture_name: "reader/text-6-pages.pdf") }

    def saved_location
      ReadingPosition.find_by(user: reader, book: book)&.location
    end

    before do
      sign_in_and_wait_as(reader)
      visit book_reader_path(book)
      wait_for_reader
    end

    it "saves a page turned right before leaving the reader" do
      turn_page(:next)
      click_link "Back"

      expect(page).to have_current_path(home_path)
      expect { saved_location }.to eventually(eq("2"))
    end

    it "saves pages turned while offline once the connection returns" do
      expect { saved_location }.to eventually(eq("1"))
      go_offline
      2.times { turn_page(:next) }
      sleep 0.5
      expect(saved_location).to eq("1")

      go_online

      expect { saved_location }.to eventually(eq("3"))
    end

    it "keeps a page turned after the session ended and saves it after signing in again" do
      turn_page(:next)
      expect { saved_location }.to eventually(eq("2"))

      Session.where(user: reader).delete_all
      turn_page(:next)
      expect(page).to have_text("Sign in again to keep saving your place")

      click_link "Sign in again"
      fill_in "email_address", with: reader.email_address
      fill_in "password", with: AuthenticationHelpers::DEFAULT_PASSWORD
      click_button "Sign in"

      wait_for_reader
      expect(reader_location).to eq("3")
      expect { saved_location }.to eventually(eq("3"))
    end
  end
end
