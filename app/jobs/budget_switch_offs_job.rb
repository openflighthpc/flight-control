class BudgetSwitchOffsJob < ApplicationJob
  queue_as :high

  def perform(project_id, slack, text)
    project = Project.find(project_id)
    begin
      msg = project.perform_budget_switch_offs(slack)
      puts msg if text
    rescue Errno::ENOENT
      puts "No config file found for project #{project.name}"
    end
  end
end
