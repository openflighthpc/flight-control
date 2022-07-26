class InstanceTypeDetail < ApplicationRecord
  validates :region, presence: true
  validates :instance_type,
            presence: true,
            uniqueness: { scope: :region, message: -> (object, _) { object.repeated_instance_type_error } }
  [:price_per_hour, :cpu, :gpu, :mem].each do |attr|
    validates attr,
              :numericality => { greater_than_or_equal_to: 0 },
              unless: -> { self[attr].nil? }
  end

  def self.keep_only_updated_entries(recent_entries, platform)
    where(platform: platform).each do |details|
      region = details.region.to_s
      instance_type = details.instance_type.to_s
      unless recent_entries[region] && recent_entries[region].include?(instance_type)
        Rails.logger.error("Database entry for region: #{region} and instance type: #{instance_type} was not updated and will be deleted.")
        find_by(instance_type: instance_type, region: region).destroy
      end
    end
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

  def repeated_instance_type_error
    'Instance type and region combination already exists'
  end

  def set_default_values(selected_attributes: nil)
    attributes_to_change = invalid_attributes(selected_attributes: selected_attributes)
    return if attributes_to_change.empty?
    attributes_to_change.each do |attr|
      assign_attributes( { attr => nil } )
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
