class Star < ApplicationRecord
  belongs_to :user
  belongs_to :repo

  validates :user_id, uniqueness: { scope: :repo_id }
end
