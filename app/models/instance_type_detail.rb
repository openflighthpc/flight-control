class InstanceTypeDetail < ApplicationRecord
  validates :region, :price_per_hour, :cpu, :gpu, :mem, :currency, presence: true
  validates :price_per_hour, :cpu, :gpu, :mem, :numericality => { :greater_than_or_equal_to => 0 }
  validates :instance_type,
            presence: true,
            uniqueness: { scope: :region, message: -> (object, _) { object.repeated_instance_type_error } }

  def record_details
    valid = valid?
    old_details = repeated_instance_type
    if old_details
      old_details.update_details(self)
    else
      raise 'No valid data to record' if valid_attributes.empty?
      set_default_values unless valid
      save!
    end
    # alert somehow about any ignored invalid attributes
  end

  def repeated_instance_type
    @instance_details ||= self.class.where(instance_type: instance_type, region: region).first
  end

  def repeated_instance_type_error
    'Instance type and region combination already exists'
  end

  def update_details(new_details)
    assign_attributes(new_details.valid_attributes)
    save! if changed?
  end

  def valid_attributes
    attributes.except(*invalid_attributes + %w(id created_at updated_at))
  end

  def invalid_attributes
    return @invalid_attributes if defined?(@invalid_attributes)
    errors = self.errors.messages
    @invalid_attributes = []
    attributes.keys.each do |attr|
      if errors.key?(attr.to_sym)
        @invalid_attributes.append(attr) unless errors[attr.to_sym].first == repeated_instance_type_error
      end
    end
    @invalid_attributes
  end

  def set_default_values
    return if invalid_attributes.empty?
    invalid_attributes.each do |attr|
      if self.class.columns_hash[attr].type == :string
        assign_attributes( { attr => 'invalid' })
      else
        assign_attributes( { attr => 0 } )
      end
    end
  end
end
