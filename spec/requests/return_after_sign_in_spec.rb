require "rails_helper"

# FR-054: a signed-out person opening a shared link signs in and lands back on that link.
# The book page itself is a later feature, so any protected URL stands in for it here.
RSpec.describe "Returning to a shared link after sign-in", type: :request do
  let(:user) { create(:user) }

  it "sends a signed-out visitor to sign-in, then back to the link they opened" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("cover.png").open, filename: "cover.png")
    shared_url = rails_blob_url(blob)

    get shared_url
    expect(response).to redirect_to(new_session_path)

    sign_in_as(user)
    expect(response).to redirect_to(shared_url)
  end
end
