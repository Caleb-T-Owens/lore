class Repo < ApplicationRecord
  NAME_FORMAT = /\A[a-z][a-z0-9-]*\z/

  belongs_to :owner, class_name: "User", inverse_of: :owned_repos
  has_many :stars, dependent: :destroy
  has_many :stargazers, through: :stars, source: :user

  before_validation :normalize_name
  before_validation :normalize_tags

  validates :name, presence: true, uniqueness: { scope: :owner_id }, format: { with: NAME_FORMAT }
  validates :description, presence: true
  validates :path, presence: true, uniqueness: true
  validate :path_is_absolute

  def clone_url
    "#{Lore::Application.config.x.lore.host}/git/#{owner.username}/#{name}.git"
  end

  def web_url
    "#{Lore::Application.config.x.lore.host}/#{owner.username}/#{name}"
  end

  def stars_count
    if association(:stars).loaded?
      stars.size
    else
      stars.count
    end
  end

  def tags
    read_json_array_attribute(:tags)
  end

  def tags=(value)
    self[:tags] = Array(value).to_json
  end

  def embedding
    raw_value = self[:embedding]
    return if raw_value.blank?

    raw_value.is_a?(String) ? JSON.parse(raw_value) : raw_value
  end

  def embedding=(value)
    self[:embedding] = value.present? ? Array(value).to_json : nil
  end

  private

  def normalize_name
    self.name = name.to_s.strip.downcase
  end

  def normalize_tags
    normalized_tags = Array(tags).filter_map do |tag|
      value = tag.to_s.strip.downcase
      value if value.present?
    end

    self.tags = normalized_tags.uniq
  end

  def read_json_array_attribute(name)
    raw_value = self[name]
    return [] if raw_value.blank?

    raw_value.is_a?(String) ? JSON.parse(raw_value) : Array(raw_value)
  end

  def path_is_absolute
    return if path.blank? || Pathname.new(path).absolute?

    errors.add(:path, "must be absolute")
  end
end
