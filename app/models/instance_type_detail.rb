class InstanceTypeDetail < ApplicationRecord
  validates :region, presence: true
  validates :instance_type,
            presence: true,
            uniqueness: { scope: :region, message: 'Instance type and region combination already exists' }
  [:price_per_hour, :cpu, :gpu, :mem].each do |attr|
    validates attr,
              :numericality => { greater_than_or_equal_to: 0 },
              unless: -> { self[attr].nil? }
  end
  validates :platform,
            presence: true,
            inclusion: {
              in: %w(aws azure example),
              message: "%{value} is not a valid platform"
            }

  def price_per_hour
    self[:price_per_hour] || 0
  end

  def cpu
    self[:cpu] || default
  end

  def gpu
    self[:gpu] || default
  end

  def mem
    self[:mem] || default
  end

  def default
    'UNKNOWN'
  end

  def missing_attributes?
    attributes.slice(*%w(mem cpu gpu price_per_hour)).values.any?(&:nil?)
  end
end
