require_relative '../models/aws_project'
require_relative '../models/cost_log'
require_relative 'aws_sdk_error'
require 'aws-sdk-costexplorer'

class AwsCostsRecorder

  def initialize(project)
    @project = project
    Aws.config.update({region: "us-east-1"})
    @explorer = Aws::CostExplorer::Client.new(access_key_id: @project.access_key_ident, secret_access_key: @project.key)
  end

  # AWS allows/requires specific filters in the query, so we make one query for each
  # cost type.
  def record_logs(date, rerun, verbose)
    end_date = date + 1.day
    Project::SCOPES.each { |scope| record_costs(date, end_date, rerun, verbose, scope) }
    # if compute groups change and we are often rerunning for past dates, 
    # we will need to change this logic to determine compute groups at 
    # the given date(s), not assume the current ones are valid
    @project.compute_groups.each do |group|
      record_costs(date, end_date, rerun, verbose, group, group)
      record_costs(date, end_date, rerun, verbose, "#{group}_storage", group)
    end
    true
  end

  # in the future will have option to create for multiple days at once
  def record_costs(start_date, end_date, rerun, verbose, scope, compute_group=nil)
    log = @project.cost_logs.find_by(date: start_date, scope: scope)

    if !log || rerun
      if compute_group
        storage = scope.include?("storage")
        cost_query = self.send("compute_group_cost_query", start_date, end_date, compute_group, storage)
      else
        cost_query = self.send("#{scope}_cost_query", start_date, end_date)
      end
      begin
        response = @explorer.get_cost_and_usage(cost_query).results_by_time
      rescue Aws::CostExplorer::Errors::ServiceError, Seahorse::Client::NetworkingError => error
        raise AwsSdkError.new("Unable to determine core costs for project #{@project.name}. #{error if @verbose}") 
      end

      # for daily report will just be one day, but multiple when run for a range
      response.each do |day|
        date = day[:time_period][:start]
        cost = day[:total]["UnblendedCost"][:amount].to_f
        log = @project.cost_logs.find_by(date: date, scope: scope)
        if rerun && log
          log.assign_attributes(cost: cost)
          log.save!
        else
          log = CostLog.create(
            project_id: @project.id,
            cost: cost,
            currency: "USD",
            date: date,
            scope: scope,
          )
        end
      end
    end
    log
  end

  private

  def total_cost_query(start_date, end_date=(start_date + 1))
    query = {
      time_period: {
        start: "#{start_date.to_s}",
        end: "#{end_date.to_s}"
      },
      granularity: "DAILY",
      metrics: ["UNBLENDED_COST"],
      filter: {
        and:[ 
          {
            not: {
              dimensions: {
                key: "RECORD_TYPE",
                values: ["CREDIT"]
              }
            }
          },
          {
            not: {
              dimensions: {
                key: "SERVICE",
                values: ["Tax"]
              }
            }
          },
        ]
      },
    }
    query[:filter][:and] << project_filter if @project.filter_level == "tag"
    query
  end

  def data_out_cost_query(start_date, end_date=(start_date + 1))
    query = total_cost_query(start_date, end_date)
    query[:filter][:and] << data_out_filter
    query
  end

  def core_cost_query(start_date, end_date=(start_date + 1))
    query = total_cost_query(start_date, end_date)
    query[:filter][:and] << { not: data_out_filter }
    query[:filter][:and] << { not: storage_filter }
    query[:filter][:and] << core_filter
    query
  end

  def core_storage_cost_query(start_date, end_date=(start_date + 1))
    query = total_cost_query(start_date, end_date)
    query[:filter][:and] << { not: data_out_filter }
    query[:filter][:and] << storage_filter
    query[:filter][:and] << core_filter
    query
  end

  # instance costs or storage costs
  def compute_group_cost_query(start_date, end_date=(start_date + 1), group, storage)
    query = total_cost_query(start_date, end_date)
    query[:filter][:and] << compute_filter
    if storage
      query[:filter][:and] << storage_filter
    else
      query[:filter][:and] += instance_run_cost_filter
    end
    query
  end

  def project_filter
    {
      tags: {
        key: "project",
        values: [@project.project_tag]
      }
    }
  end

  def core_filter
    {
      tags: {
        key: "type",
        values: ["core"]
      }
    }
  end

  def compute_group_filter(group)
    {
      tags: {
        key: "compute_group",
        values: [group]
      }
    }
  end

  def data_out_filter
    {
      dimensions: {
        key: "USAGE_TYPE_GROUP",
        values: 
          [
            "EC2: Data Transfer - Internet (Out)",
            "EC2: Data Transfer - CloudFront (Out)",
            "EC2: Data Transfer - Region to Region (Out)"
          ]
      }
    }
  end

  def storage_filter
    { 
      dimensions: {
        key: "USAGE_TYPE_GROUP",
        values: 
          [
            "S3: Storage - Standard",
            "EC2: EBS - I/O Requests",
            "EC2: EBS - Magnetic",
            "EC2: EBS - Provisioned IOPS",
            "EC2: EBS - SSD(gp2)",
            "EC2: EBS - SSD(io1)",
            "EC2: EBS - Snapshots",
            "EC2: EBS - Optimized"
          ]
      }
    }
  end

  def instance_run_cost_filter
    [
      {
        dimensions: {
          key: "USAGE_TYPE_GROUP",
          values: ["EC2: Running Hours"]
        }
      },
      {
        dimensions: {
          key: "SERVICE",
          values: ["Amazon Elastic Compute Cloud - Compute"]
        }
      }
    ]
  end

  def compute_filter
    {
      tags: {
        key: "type",
        values: ["compute"]
      }
    }
  end

  def compute_group_filter(group)
    {
      tags: {
        key: "compute_group",
        values: [group]
      }
    }
  end
end
