module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    # Background JSON requests (the reader saving its position) get a 401 instead of a
    # redirect, so the client can tell "signed out" from "saved" (002 research R5).
    def request_authentication
      return head(:unauthorized) if request.format.json?

      session[:return_to_after_authenticating] = request.url
      redirect_to main_app.new_session_path
    end

    # Sign-in and sign-up are pointless once signed in (002 FR-042).
    def redirect_if_authenticated
      redirect_to root_path if authenticated?
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || home_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
