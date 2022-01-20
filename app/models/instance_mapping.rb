class InstanceMapping < ApplicationRecord
  @@mappings = nil
  validates :instance_type, presence: true, uniqueness: true
  validates :customer_facing_type, presence: true, uniqueness: { scope: :platform }
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure),
      message: "%{value} is not a valid platform"
    }

  def self.instance_mappings
    if !@@mappings
      @@mappings = {}
      InstanceMapping.all.each do |mapping|
        if !@@mappings[mapping.platform]
          @@mappings[mapping.platform] = {
            mapping.instance_type => mapping.customer_facing_type
          }
        else
          @@mappings[mapping.platform][mapping.instance_type] = mapping.customer_facing_type
        end
      end
    end
    @@mappings
  end
end
