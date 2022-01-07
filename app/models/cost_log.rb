class CostLog < ApplicationRecord
  belongs_to :project
  validates :cost, :currency, :scope, :date, presence: true
end
