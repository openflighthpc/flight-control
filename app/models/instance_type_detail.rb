class InstanceTypeDetail < ApplicationRecord
  validates :region, :price_per_hour, :cpu, :gpu, :mem, :currency, presence: true
  validates :instance_type,
            presence: true,
            uniqueness: { scope: :region, message: 'Instance type and region combination already exists' }

  def repeated_instance_type
    @old_details ||= self.class.where(instance_type: instance_type, region: region).first
  end

  def repeated_instance_type?
    !repeated_instance_type.empty?
  end

  def update_details(new_details)
    assign_attributes(new_details)
    save! if changed?
  end
end
