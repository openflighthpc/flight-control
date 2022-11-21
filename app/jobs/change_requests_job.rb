class ChangeRequestsJob < ApplicationJob
  queue_as :default

  def perform(project_id, slack, text)
    project = Project.find(project_id)
    begin
      project.action_scheduled(slack, text)
    rescue Errno::ENOENT
      puts "No config file found for project #{project.name}"
    end
  end
end

