require_relative "../../app/models/application_record"
require_relative '../project_manager'

namespace :projects do
  desc "Create or update a project"
  task :manage => :environment do |task, args|
    ProjectManager.new.add_or_update_project
  end
end
