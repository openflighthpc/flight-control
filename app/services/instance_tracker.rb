class InstanceTracker
  ON_STATUSES = ["VM running", "running"]

  def initialize(project)
    @project = project
  end

  def latest_instances
    if !@latest_instances
      logs = @project.latest_instance_logs
      instance_mappings = InstanceMapping.where(platform: @project.platform)
  
      groups = @project.front_end_compute_groups

      all_instances = {}
      groups.each do |node_group, values|
        instances = []
        region = values["region"]
        group_logs = logs.where(compute_group: node_group)
        instance_mappings.each do |mapping|
          instance = Instance.new(mapping.instance_type, region, node_group, @project.platform, @project)
          if instance.node_limit > 0 && instance.present_in_region?
            group_logs.where(instance_type: mapping.instance_type).each do |log|
              puts "here"
              instance.increase_count(ON_STATUSES.include?(log.status) ? :on : :off)
            end
            instances << instance
          end
        end

        # add any unmapped instances
        logs_without_mapping = group_logs.map {|log| log.has_mapping? ? nil : log.id }.compact
        grouped = group_logs.where("id IN (?)", logs_without_mapping).group(:instance_type, :status).count
        last = nil
        grouped.each do |group|
          if !last || last && group[0][0] != last.instance_type
            instance = Instance.new(group[0][0], region, node_group, @project.platform, @project)
            instance.increase_count(ON_STATUSES.include?(group[0][1]) ? :on : :off, group[1])
            instances << last if last && last.present_in_region?
            last = instance
          elsif last
            last.increase_count(ON_STATUSES.include?(group[0][1]) ? :on : :off, group[1])
          end
        end
        instances << last if last && last.present_in_region?

        all_instances[node_group] = instances
      end
      @latest_instances = all_instances
    end
    @latest_instances
  end
end
