class ComputeGroupConfig < ApplicationRecord
  belongs_to :project
  has_many :instance_type_configs
  accepts_nested_attributes_for :instance_type_configs

  default_scope { order(:priority) }

  validates :region, :colour, :storage_colour, :priority, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 1 }
  validates :name, presence: true, uniqueness: { scope: :project }
end
