class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def current_api_user
    @current_api_user ||= Lore::Auth.user_from_bearer_header(request.authorization)
  end

  def require_api_user!
    head :unauthorized unless current_api_user
  end
end
