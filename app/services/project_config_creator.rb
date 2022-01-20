require_relative '../models/project'

class ProjectConfigCreator
  EXAMPLE_COLOURS = %w[0722ef ef2d07 ef07bd 098765]

  def initialize(project)
    @project = project
  end

  def create_config(overwrite=false)
    if overwrite && File.exists?(File.join(File.dirname(__FILE__), "../../config/projects/#{@project.name}.yaml"))
      config = YAML.load_file(File.join(File.dirname(__FILE__), "../../config/projects/#{@project.name}.yaml"))
    else
      config = YAML.load_file(File.join(File.dirname(__FILE__), "../../config/projects/default.yaml"))
    end
    config["compute_groups"] = {}
    groups = groups = @project.latest_instance_logs.pluck(:compute_group, :region).uniq { |group| group[0] }.sort
    if groups.empty?
      puts "No instance logs with a compute tag recorded for project #{@project.name}."
      puts "Please retry after creating at least one instance with a compute group tag and running the cloud-cost-reporter.\n\n"
    else
      priority = 1
      colour_index = 0
      groups.each do |details|
        group_name = details[0]
        region = details[1]
        config["compute_groups"][group_name] = {
          "priority" => priority,
          "region" => region,
          "colour" => EXAMPLE_COLOURS[colour_index],
          "nodes" => {}
        }
        priority += 1
        colour_index = (colour_index + 1) % EXAMPLE_COLOURS.length # if more groups than colours, repeat from start of colours list
      end

      counts = @project.latest_instance_logs.group(:compute_group, :instance_type).count
      counts.each do |details, count|
        group_name = details[0]
        instance_type = details[1]
        customer_facing = InstanceMapping.instance_mappings[@project.platform][instance_type]
        customer_facing ||= "Compute (Other)"
        customer_facing = customer_facing.downcase.gsub(' ', '_').gsub(/[()]/, '')
        config["compute_groups"][group_name]["nodes"][customer_facing] = {
          "priority" => 1,
          "limit" => count
        }
      end
      File.open(File.join(File.dirname(__FILE__), "../../config/projects/#{@project.name}.yaml"), "w") { |file| file.write(config.to_yaml) }
      puts "Config file created for project #{@project.name} in folder /config/projects."
      print "Please review and update the file as required, "
      print "including setting priorities and compute group colours.\n\n"
    end
  end
end
