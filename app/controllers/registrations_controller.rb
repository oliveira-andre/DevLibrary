# Sign-up (002 US8, research R15). Always creates a reader: `role` is never permitted, and
# the 001 `:sign_up` context makes the name required.
class RegistrationsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access only: %i[ new create ]
  before_action :redirect_if_authenticated, only: :new
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save(context: [ :create, :sign_up ])
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def registration_params
      params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
    end
end
