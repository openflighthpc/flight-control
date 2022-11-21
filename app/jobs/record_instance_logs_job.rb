class RecordInstanceLogsJob < ApplicationJob
  queue_as :default

  def perform(project_id, rerun, verbose)
    project = Project.find(project_id)
    begin
      msg = "Project #{project.name}: "
      msg << project.record_instance_logs(rerun, verbose)
      puts msg
    rescue AzureApiError, AwsSdkError => e
      error = <<~MSG
          Generation of instance logs for project *#{project.name}* stopped due to error:
          #{e}
      MSG

      error << "\n#{"_" * 50}"
      puts error.gsub("*", "")
    end
  end
end
