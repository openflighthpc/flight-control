class RecordInstanceDetailsJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find(project_id)
    project.record_instance_details
  end
end
