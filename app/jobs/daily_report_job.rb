class DailyReportJob < ApplicationJob
  queue_as :default

  def perform(project_id, date, rerun, slack, text, verbose)
    project = Project.find(project_id)
    begin
      project.daily_report(date, rerun, slack, text, verbose)
    rescue AzureApiError, AwsSdkError => e
      error = <<~MSG
          Generation of daily report for project *#{project.name}* stopped due to error:
          #{e}
      MSG

      project.send_slack_message(error) if slack
      error << "\n#{"_" * 50}"
      puts error.gsub("*", "")
    end
  end
end
