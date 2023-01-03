class MonitorJob < ApplicationJob
  queue_as :medium

  def perform(project_id)
    project = Project.find(project_id)
    if project.monitor_currently_active?
      project.check_and_switch_off_idle_nodes(true)
    end
  end
end
