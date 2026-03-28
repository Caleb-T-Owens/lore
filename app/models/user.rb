require "digest"

class User < ApplicationRecord
  USERNAME_FORMAT = /\A[a-z][a-z0-9-]*\z/
  PAT_PREFIX = "lore_pat_"

  has_many :owned_repos, class_name: "Repo", foreign_key: :owner_id, inverse_of: :owner, dependent: :destroy
  has_many :stars, dependent: :destroy
  has_many :starred_repos, through: :stars, source: :repo

  before_validation :normalize_username
  before_validation :issue_pat, on: :create

  validates :username, presence: true, uniqueness: true, format: { with: USERNAME_FORMAT }
  validates :pat_digest, presence: true

  attr_reader :plain_pat

  def self.digest_pat(token)
    Digest::SHA256.hexdigest(token)
  end

  def authenticate_pat(token)
    return false if token.blank? || pat_digest.blank?

    if ActiveSupport::SecurityUtils.secure_compare(pat_digest, self.class.digest_pat(token))
      self
    else
      false
    end
  end

  private

  def normalize_username
    self.username = username.to_s.strip.downcase
  end

  def issue_pat
    return if pat_digest.present?

    @plain_pat = "#{PAT_PREFIX}#{SecureRandom.urlsafe_base64(24)}"
    self.pat_digest = self.class.digest_pat(@plain_pat)
  end
end
