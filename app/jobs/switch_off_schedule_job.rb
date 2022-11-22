class SwitchOffScheduleJob < ApplicationJob
  queue_as :low

  def perform(project_id, slack, text)
    project = Project.find(project_id)
    begin
      msg = project.budget_switch_off_schedule(slack)
      puts msg if text
    rescue StandardError => e
      puts "Error determining over budget switch offs for #{project.name}: #{e.message}"
    end
  end
end
