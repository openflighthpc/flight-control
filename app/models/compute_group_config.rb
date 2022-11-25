class ComputeGroupConfig < ApplicationRecord
  belongs_to :project
  has_many :instance_type_configs

  validates :region, :colour, :storage_colour, :priority, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 1 }
end
