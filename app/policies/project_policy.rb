class ProjectPolicy < ApplicationPolicy
  def show?
    user && (user.admin? || user.has_role_for?(record))
  end

  def policy_page?
    user && (user.admin? || user.has_role_for?(record, 'default'))
  end

  alias_method :billing_management?, :show?
  alias_method :data_check?, :show?
  alias_method :costs_breakdown?, :show?
end
