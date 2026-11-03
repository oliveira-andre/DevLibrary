require "rails_helper"

RSpec.describe "Registrations", type: :request do
  let(:valid_params) do
    { user: { name: "Ana", email_address: " Ana@Example.COM ", password: "password123", password_confirmation: "password123" } }
  end

  describe "GET /registration/new" do
    it "shows the sign-up card with the wordmark" do
      get new_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css(".auth-card img[alt='Dev Library']")).to be_present
      expect(response.parsed_body.at_css("h1").text).to eq("Create your account")
    end

    it "sends a signed-in person home" do
      sign_in_as(create(:user))

      get new_registration_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /registration" do
    it "creates a reader with a normalized email, signs them in and goes home" do
      expect { post registration_path, params: valid_params }.to change(User, :count).by(1)

      user = User.last
      expect(user).to have_attributes(name: "Ana", email_address: "ana@example.com", role: "reader")
      expect(user.sessions.count).to eq(1)
      expect(response).to redirect_to(home_url)
    end

    it "ignores a smuggled admin role" do
      post registration_path, params: valid_params.deep_merge(user: { role: "admin" })

      expect(User.last).to be_reader
    end

    it "requires a name, keeping the typed name and email but never the password" do
      post registration_path, params: valid_params.deep_merge(user: { name: "" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name can&#39;t be blank")
      page = response.parsed_body
      expect(page.at_css("input[name='user[email_address]']")["value"]).to eq(" Ana@Example.COM ") # as typed
      expect(page.at_css("input[name='user[password]']")["value"]).to be_nil
      expect(page.at_css("input[name='user[password_confirmation]']")["value"]).to be_nil
    end

    it "rejects an email already in use in another case" do
      create(:user, email_address: "ana@example.com")

      post registration_path, params: valid_params.deep_merge(user: { email_address: "ANA@example.com" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Email address has already been taken")
    end

    it "rejects a short password" do
      post registration_path, params: valid_params.deep_merge(user: { password: "short", password_confirmation: "short" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Password is too short (minimum is 8 characters)")
    end

    it "rejects a confirmation that does not match" do
      post registration_path, params: valid_params.deep_merge(user: { password_confirmation: "different123" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Password confirmation doesn&#39;t match Password")
    end

    it "limits sign-ups per IP" do
      allow(RegistrationsController.cache_store).to receive(:increment).and_return(11)

      post registration_path, params: valid_params

      expect(response).to redirect_to(new_registration_path)
      expect(flash[:alert]).to eq("Try again later.")
    end
  end
end
