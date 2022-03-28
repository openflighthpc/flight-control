class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def formatted_timestamp
    created_at.strftime('%-I:%M%P %F')
  end
end
