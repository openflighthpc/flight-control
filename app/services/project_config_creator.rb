require_relative '../models/project'

class ProjectConfigCreator
  EXAMPLE_COLOURS = %w[0722ef ef0235 ef07bd 098765]

  def initialize(project)
    @project = project
  end

  def create_config(overwrite=false)
    if !overwrite && @project.compute_group_configs.exists?
      puts "Config records already exists for project #{@project.name}."
      puts "Please run again with 'overwrite' set to 'true' if you wish to update these."
      return
    end
    groups = groups = @project.latest_instance_logs.pluck(:compute_group, :region).uniq { |group| group[0] }.sort
    if groups.empty?
      puts "No instance logs with a compute tag recorded for project #{@project.name}."
      puts "Please retry after creating at least one instance with a compute group tag and running the instance logs rake task.\n\n"
    else
      current_group_config_ids = []
      current_instance_config_ids = []
      priority = 1
      colour_index = 0
      groups.each do |details|
        group_name = details[0]
        region = details[1]
        compute_group = @project.compute_group_configs.find_or_initialize_by(name: group_name)
        compute_group.priority ||= priority
        compute_group.region ||= region
        compute_group.colour ||= EXAMPLE_COLOURS[colour_index]
        compute_group.storage_colour ||= EXAMPLE_COLOURS[colour_index]
        compute_group.save!

        current_group_config_ids << compute_group.id
        priority += 1
        colour_index = (colour_index + 1) % EXAMPLE_COLOURS.length # if more groups than colours, repeat from start of colours list
      end

      counts = @project.latest_instance_logs.group(:compute_group, :instance_type).count
      counts.each do |details, count|
        group_name = details[0]
        group = @project.compute_group_configs.find_by(name: group_name)
        instance_type = details[1]
        instance_config = InstanceTypeConfig.find_or_initialize_by(compute_group_config: group, instance_type: instance_type)
        instance_config.project = @project
        instance_config.priority ||= priority
        instance_config.limit ||= count
        instance_config.save!

        current_instance_config_ids << instance_config.id
      end

      @project.compute_group_configs.where.not(id: current_group_config_ids).destroy_all
      @project.instance_type_configs.where.not(id: current_instance_config_ids).destroy_all

      puts "Config created for project #{@project.name}."
      print "Please review and update the records as required, "
      print "including setting priorities and compute group colours.\n"
    end
  end
end
