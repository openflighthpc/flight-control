class RecordCostLogsJob < ApplicationJob
  queue_as :default

  def perform(project_id, date, rerun, text, verbose)
    project = Project.find(project_id)
    begin
      print "Project #{project.name}: " if text
      project.record_cost_logs(date, rerun, text, verbose)
      puts if text
    rescue AzureApiError, AwsSdkError => e
      error = <<~MSG
    Generation of cost logs for project *#{project.name}* stopped due to error:
    #{e}
      MSG

      error << "\n#{"_" * 50}"
      puts error.gsub("*", "")
    end
  end
end
