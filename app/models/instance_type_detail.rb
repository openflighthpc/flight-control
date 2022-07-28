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

  def currency
    self[:currency] || default
  end

  def platform
    self[:platform] || default
  end

  def default
    'UNKNOWN'
  end

  def missing_attributes?
    attributes.except(*%w(id created_at updated_at)).values.any?(&:nil?)
  end
end
