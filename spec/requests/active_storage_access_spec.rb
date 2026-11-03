require "rails_helper"

RSpec.describe "Active Storage access", type: :request do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: file_fixture("cover.png").open, filename: "cover.png")
  end

  it "sends signed-out visitors to the sign-in page" do
    get rails_blob_path(blob)

    expect(response).to redirect_to(new_session_path)
  end

  it "serves the file to signed-in users" do
    sign_in_as(create(:user))

    get rails_blob_path(blob)

    expect(response).to have_http_status(:redirect)
    expect(response.location).not_to include(new_session_path)
  end
end
