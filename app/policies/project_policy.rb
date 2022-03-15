class ProjectPolicy < ApplicationPolicy
  def show?
    return false if user.nil?
    return true if user.admin?
    return true if user.has_role_for?(record)
  end

  def create_event?
    return false if user.nil?
    return true if user.admin
    return true if user.has_role_for?(record, 'standard')
  end
end
