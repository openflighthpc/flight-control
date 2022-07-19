class InstanceTypeDetail < ApplicationRecord
  validates :region, :price_per_hour, :cpu, :gpu, :mem, :currency, presence: true
  validates :price_per_hour, :cpu, :gpu, :mem, :numericality => { :greater_than_or_equal_to => -1 }
  validates :instance_type,
            presence: true,
            uniqueness: { scope: :region, message: -> (object, _) { object.repeated_instance_type_error } }

  def record_details
    set_default_values
    old_details = repeated_instance_type
    old_details ? old_details.update_details(self) : save!
  end

  def repeated_instance_type
    @instance_details ||= self.class.where(instance_type: instance_type, region: region).first
  end

  def repeated_instance_type_error
    'Instance type and region combination already exists'
  end

  def update_details(new_details)
    assign_attributes(new_details.attributes.except(*attributes_not_to_update))
    save! if changed?
  end

  def valid_attributes
    attributes.except(*invalid_attributes + attributes_not_to_update)
  end

  def invalid_attributes
    return @invalid_attributes if defined?(@invalid_attributes)
    valid?
    errors = self.errors.messages
    @invalid_attributes = []
    attributes.each do |attr, value|
      invalid_number = value.is_a?(Numeric) ? (value < 0) : false
      if errors.key?(attr.to_sym) || invalid_number
        @invalid_attributes.append(attr) unless errors[attr.to_sym].first == repeated_instance_type_error
      end
    end
    @invalid_attributes
  end
  
  def attributes_not_to_update
    %w(instance_type region id created_at updated_at)
  end

  def set_default_values
    return if invalid_attributes.empty?
    invalid_attributes.each do |attr|
      if self.class.columns_hash[attr].type == :string
        assign_attributes( { attr => 'INVALID' } )
      else
        assign_attributes( { attr => -1 } )
      end
    end
  end
end
