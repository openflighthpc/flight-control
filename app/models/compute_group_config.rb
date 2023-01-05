class ComputeGroupConfig < ApplicationRecord
  belongs_to :project
  has_many :instance_type_configs
  accepts_nested_attributes_for :instance_type_configs

  default_scope { order(:priority) }
  scope :active, -> { where("archived_date IS NULL OR archived_date > ?", Date.current) }

  def current_instance_type_configs
    instance_type_configs.active
  end

  validates :region, :colour, :storage_colour, :priority, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 1 }
  validate :name_uniqueness

  private

  def name_uniqueness
    if archived_date.nil? && project.compute_group_configs.active.where(name: self.name).where.not(id: self.id).exists?
      errors.add(:name, "already used")
    end
  end
end
