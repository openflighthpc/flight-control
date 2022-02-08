require_relative "../../app/models/application_record"
require_relative "../../app/models/instance_mapping"
require 'table_print'

namespace :instance_mappings do
  desc "Create or new instance mapping"
  task :new, [:platform, :instance_type, :customer_facing] => :environment do |task, args|
    mapping = InstanceMapping.new(platform: args["platform"],
                                  instance_type: args["instance_type"],
                                  customer_facing_type: args["customer_facing"])
    if mapping.valid?
      mapping.save!
      puts "Mapping created for #{mapping.platform}: #{mapping.instance_type} => #{mapping.customer_facing_type}"
    else
      print "Unable to create mapping: "
      print mapping.errors.full_messages.join(", ")
      puts
    end
  end

  desc "Update instance mapping"
  task :update, [:platform, :instance_type, :new_customer_facing] => :environment do |task, args|
    mapping = InstanceMapping.find_by(platform: args["platform"], instance_type: args["instance_type"])
    if !mapping
      puts "Mapping for #{args["instance_type"]} on #{args["platform"]} not found"
    else
      mapping.customer_facing_type = args["new_customer_facing"]
      if mapping.valid?
        mapping.save!
        puts "Mapping for #{args["instance_type"]} on #{args["platform"]} updated"
      else
        print "Unable to update mapping: "
        print mapping.errors.full_messages.join(", ")
        puts
      end
    end
  end

  desc "Delete instance mapping"
  task :delete, [:platform, :instance_type] => :environment do |task, args|
    mapping = InstanceMapping.find_by(platform: args["platform"], instance_type: args["instance_type"])
    if !mapping
      puts "Mapping for #{args["instance_type"]} on #{args["platform"]} not found"
    else
      success = mapping.delete
      if success
        puts "Mapping deleted" 
      else
        puts "Error deleting mapping"
      end
    end
  end

  desc 'List all instance mappings'
  task :list => :environment do |task, args|
    tp InstanceMapping.all, :platform, :instance_type, :customer_facing_type
  end
end
