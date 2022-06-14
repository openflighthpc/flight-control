require_relative "../../app/models/project"
require_relative "../../app/services/funds_manager"

namespace :funds do
  namespace :check_balance do
    desc "check and record hub balance for one project"
    task :by_project, [:project] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        FundsManager.new(project).check_and_update_hub_balance
      end
    end

    desc "check and record hub balance for all active projects"
    task :all => :environment do |task, args|
      Project.active.each do |project|
        begin
          FundsManager.new(project).check_and_update_hub_balance
        rescue
          # error handling?
        end
      end
    end
  end

  namespace :send_and_receive do
    desc "send back unused and request this cycle's budget from Hub, for one project"
    task :by_project, [:project] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        FundsManager.new(project).start_of_cycle_actions
      end
    end

    desc "send back unused and request this cycle's budget from Hub, for one project"
    task :all => :environment do |task, args|
      Project.active.each do |project|
        begin
          FundsManager.new(project).start_of_cycle_actions
        rescue
          # error handling?
        end
      end
    end
  end
 end