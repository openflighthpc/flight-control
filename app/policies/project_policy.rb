class ProjectPolicy < ApplicationPolicy
  def billing_management?
    show?
  end

  def data_check?
    show?
  end

  def costs_breakdown?
    show?
  end

  def show?
    return false if user.nil?
    return true if user.admin?
    return true if user.has_role_for?(record)
  end

  def create_event?
    return false if user.nil?
    return true if user.admin?
    return true if user.has_role_for?(record, 'default')
  end
end
