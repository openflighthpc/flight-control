require_relative 'project'
require_relative 'services/aws_instance_recorder'

class AwsProject < Project
  alias_attribute :access_key_ident, :security_id
  alias_attribute :key, :security_key
  validates :regions, presence: true
  validates :filter_level,
    presence: true,
    inclusion: {
      in: %w(tag account),
      message: "%{value} is not a valid filter level. Must be tag or account."
    }
  validate :project_tag_if_tag_filter
  validate :regions_not_empty

  default_scope { where(platform: "aws") }

  def describe_regions
    regions.join(", ")
  end

  private

  def project_tag_if_tag_filter
    errors.add(:project_tag, "Must be defined if filter level is tag") if filter_level == "tag" && !project_tag
  end

  def regions_not_empty
    errors.add(:regions, "Must contain at least one value") if regions.empty?
  end
end
