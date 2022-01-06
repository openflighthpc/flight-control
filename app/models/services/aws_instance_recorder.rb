require_relative '../aws_project'
require_relative '../instance_log'
require_relative 'aws_sdk_error'
require 'aws-sdk-ec2'

class AwsInstanceRecorder

  def initialize(project)
    @project = project
  end

  def record_instance_logs(rerun=false)
    # can't record instance logs if resource group deleted
    if @project.archived
      return "Logs not recorded, project is archived"
    end

    outcome = ""
    today_logs = @project.instance_logs.where(date: Date.today)
    if today_logs.any?
      if rerun 
        outcome = "Overwriting existing logs. "
      else
        return "Logs already recorded for today. Run script again with 'rerun' to overwrite existing logs."
      end
    else
      outcome = "Writing new logs for today. "
    end

    any_nodes = false
    log_recorded = false
    if !today_logs.any? || rerun
      @project.regions.each do |region|
        begin
          instances_checker = Aws::EC2::Client.new(access_key_id: @project.access_key_ident, secret_access_key: @project.key, region: region)
          results = nil
          results = instances_checker.describe_instances(project_instances_query)
        rescue Aws::EC2::Errors::ServiceError, Seahorse::Client::NetworkingError => error
          raise AwsSdkError.new("Unable to determine AWS instances for project #{@project.name} in region #{region}. #{error if @verbose}")
        rescue Aws::Errors::MissingRegionError => error
          raise AwsSdkError.new("Unable to determine AWS instances for project #{@project.name} due to missing region. #{error if @verbose}")  
        end
        results.reservations.each do |reservation|
          any_nodes = true if reservation.instances.any?
          reservation.instances.each do |instance|
            named = ""
            compute = false
            compute_group = nil
            instance.tags.each do |tag|
              if tag.key == "Name"
                named = tag.value
              end
              if tag.key == "type"
                compute = tag.value == "compute"
              end
              if tag.key == "compute_group"
                compute_group = tag.value
              end
            end

            log = InstanceLog.create(
              instance_id: instance.instance_id,
              project_id: @project.id,
              instance_name: named,
              instance_type: instance.instance_type,
              compute_group: compute_group,
              status: instance.state.name,
              platform: "aws",
              region: region,
              date: Date.today
            )
            log_recorded = true if log.valid? && log.persisted?
          end
        end
      end
    end
    outcome << (log_recorded ? "Logs recorded" : (any_nodes ? "Logs NOT recorded" : "No logs to record"))
    outcome
  end

  def project_instances_query
    query = {
      filters: [
        {
          name: "tag:type",
          values: ["compute"]
        }
      ], 
    }
    query[:filters] << tag_filter if @project.filter_level == "tag"
    query
  end

  def tag_filter
    {
      name: "tag:project", 
      values: [@project.project_tag], 
    }
  end
end
