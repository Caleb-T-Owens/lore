require "base64"

module Lore
  module Auth
    module_function

    def user_from_bearer_header(header)
      user_from_token(extract_bearer_token(header))
    end

    def user_from_basic_header(header)
      username, token = extract_basic_credentials(header)
      return unless username && token

      user = User.find_by(username: username)
      user if user&.authenticate_pat(token)
    end

    def user_from_token(token)
      return if token.blank?

      User.find_by(pat_digest: User.digest_pat(token))
    end

    def extract_bearer_token(header)
      match = header.to_s.match(/\ABearer\s+(?<token>\S+)\z/)
      match&.[](:token)
    end

    def extract_basic_credentials(header)
      scheme, encoded = header.to_s.split(" ", 2)
      return if scheme != "Basic" || encoded.blank?

      username, token = Base64.strict_decode64(encoded).split(":", 2)
      return if username.blank? || token.blank?

      [username, token]
    rescue ArgumentError
      nil
    end
  end
end
