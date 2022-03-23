class ChangeRequestPolicy < ApplicationPolicy
  def show?
    user && (user.admin? || user.has_role_for?(record.project))
  end

  def create?
    user && (user.admin? || user.has_role_for?(record.project, 'default'))
  end

  alias_method :manage?, :show?
  alias_method :latest?, :show?
  alias_method :new?, :create?
  alias_method :costs_forecast?, :create?
  alias_method :edit?, :create?
  alias_method :update?, :create?
  alias_method :cancel?, :create?
end
