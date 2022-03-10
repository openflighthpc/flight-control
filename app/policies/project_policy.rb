class ProjectPolicy
  attr_reader :user, :project

  def initialize(user:, project:)
    @user = user
    @project = project
  end

  def show?
    return false if @user.nil?
    return true if @user.admin?
    return true if @user.has_role_for?(@project)
  end
end
