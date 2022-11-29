require_relative '../models/project'

class ProjectConfigCreator
  EXAMPLE_COLOURS = %w[#0722ef #ef0235 #ef07bd #098765]

  def initialize(project)
    @project = project
  end

  def create_config(update=false)
    result = {}
    if !update && @project.compute_group_configs.exists?
      msg = "Config records already exists for project #{@project.name}.\n"
      msg << "Please run again with 'overwrite' set to 'true' if you wish to update these."
      result["error"] = msg
      return result
    end
    groups = @project.latest_instance_logs.pluck(:compute_group, :region).uniq { |group| group[0] }.sort
    if groups.empty?
      msg = "No instance logs with a compute tag recorded for project #{@project.name}.\n"
      msg << "Please retry after creating at least one instance with a compute group tag and running the instance logs rake task.\n"
      result["error"] = msg
      return result
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
        result["added group(s)"] = true if compute_group.id.nil?
        compute_group.save!

        counts = @project.latest_instance_logs.where(compute_group: group_name).group(:instance_type).count
        instance_priority = 1
        counts.each do |instance_type, count|
          instance_config = InstanceTypeConfig.find_or_initialize_by(compute_group_config: compute_group, instance_type: instance_type)
          instance_config.project = @project
          instance_config.priority ||= instance_priority
          instance_config.limit = count
          result["updated count(s)"] = true if instance_config.limit_changed? && instance_config.id
          result["added instance type(s)"] = true if instance_config.id.nil?
          instance_config.save!

          current_instance_config_ids << instance_config.id
          instance_priority += 1
        end

        current_group_config_ids << compute_group.id
        priority += 1
        colour_index = (colour_index + 1) % EXAMPLE_COLOURS.length # if more groups than colours, repeat from start of colours list
      end

      result["removed group(s)"] = @project.compute_group_configs.where.not(id: current_group_config_ids).destroy_all.count > 0
      result["removed instance type(s)"] = @project.instance_type_configs.where.not(id: current_instance_config_ids).destroy_all.count > 0
      result["changed"] = result.any? {| k, v| v }
      return result
    end
  end
end
