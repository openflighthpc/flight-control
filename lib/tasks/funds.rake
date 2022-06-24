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

  namespace :check_and_update_funds do
    desc "check and carry out fund transfers, if needed, for one project"
    task :by_project, [:project] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        FundsManager.new(project).check_and_manage_funds
      end
    end

    desc "check and carry out fund transfers, if needed, for all projects"
    task :all => :environment do |task, args|
      Project.active.each do |project|
        begin
          FundsManager.new(project).check_and_manage_funds
        rescue
          # error handling?
        end
      end
    end
  end
end
