class InstanceTypeDetail < ApplicationRecord
  validates :region, :currency, presence: true
  validates :price_per_hour, :cpu, :gpu, :mem,
            allow_nil: true,
            :numericality => { :greater_than_or_equal_to => 0 }
  validates :instance_type,
            presence: true,
            uniqueness: { scope: :region, message: -> (object, _) { object.repeated_instance_type_error } }

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

  def repeated_instance_type
    @instance_details ||= self.class.find_by(instance_type: instance_type, region: region)
  end

  def repeated_instance_type_error
    'Instance type and region combination already exists'
  end

  def set_default_values(selected_attributes: nil)
    attributes_to_change = invalid_attributes(selected_attributes: selected_attributes)
    return if attributes_to_change.empty?

    attributes_to_change.each do |attr|
      if self.class.columns_hash[attr].type == :string
        assign_attributes( { attr => 'UNKNOWN' } )
      else
        assign_attributes( { attr => nil } )
      end
    end
  end

  def update_details(new_details, selected_attributes)
    return if selected_attributes.empty?
    assign_attributes(new_details.attributes
                                 .except(*attributes_not_to_update)
                                 .slice(*selected_attributes.map { |a| a.to_s }))
    save! if changed?
  end

  def invalid_attributes(selected_attributes: nil)
    return @invalid_attributes if defined?(@invalid_attributes)
    valid?
    errors = self.errors.messages
    @invalid_attributes = []
    if selected_attributes
      attributes_to_check = attributes.slice( *selected_attributes.map { |a| a.to_s } )
    else
      attributes_to_check = attributes.except(*%w(id created_at updated_at))
    end
    attributes_to_check.each do |attr, value|
      if errors.key?(attr.to_sym) || value.nil?
        @invalid_attributes.append(attr) unless errors[attr.to_sym].first == repeated_instance_type_error
      end
    end
    @invalid_attributes
  end

  def attributes_not_to_update
    %w(instance_type region id created_at updated_at)
  end
end
