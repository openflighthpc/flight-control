class InstanceTracker
  def initialize(project)
    @project = project
    @platform = @project.platform
  end

  def latest_instances
    if !@latest_instances
      logs = @project.latest_instance_logs
      instance_mappings = InstanceMapping.where(platform: @platform)
  
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
              instance.increase_count(InstanceLog::ON_STATUSES[@platform] == log.status ? :on : :off)
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
            instance.increase_count(InstanceLog::ON_STATUSES[@platform] == group[0][1] ? :on : :off, group[1])
            instances << last if last && last.present_in_region?
            last = instance
          elsif last
            last.increase_count(InstanceLog::ON_STATUSES[@platform] == group[0][1] ? :on : :off, group[1])
          end
        end
        instances << last if last && last.present_in_region?

        all_instances[node_group] = instances
      end
      changes = pending_action_log_changes
      all_instances.each do |group, instances|
        instances.each do |instance|
          change = changes.dig(group, instance.instance_type)
          if change
            pending_count = change += instance.pending_on
          end
          instance.set_pending_on(pending_count) if pending_count
        end
      end
      @latest_instances = all_instances
    end
    @latest_instances
  end

  def pending_action_log_changes
    changes = {}
    # we only want the latest action log for an instance id
    logs = @project.pending_action_logs.select { |log| !log.has_next? }
    logs.each do |log|
      value = log.action == "on" ? 1 : -1
      # If the same as actual (i.e this undoes a previous change) 
      # it won't impact counts , but we still want to include it 
      # here so we can highlight there is a pending change.
      value = 0 if log.same_action_as_latest_actual?
      if changes.has_key?(log.compute_group)
        if changes[log.compute_group].has_key?(log.instance_type)
          changes[log.compute_group][log.instance_type] += value
        else
          changes[log.compute_group][log.instance_type] = value
        end
      else
        changes[log.compute_group] = {log.instance_type => value}
      end
    end
    changes
  end
end
