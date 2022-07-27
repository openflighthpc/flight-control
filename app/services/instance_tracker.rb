class InstanceTracker
  def initialize(project)
    @project = project
    @platform = @project.platform
  end

  def latest_instances(temp_change_request)
    return @latest_instances if @latest_instances
    changes = pending_action_log_changes
    all_instances = latest_instance_count
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
    set_future_changes(temp_change_request)
    @latest_instances
  end

  def latest_instance_count
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
        if instance.node_limit > 0
          group_logs.where(instance_type: mapping.instance_type).each do |log|
            instance.increase_count(InstanceLog::ON_STATUSES[@platform] == log.status ? :on : :off)
          end
          instances << instance
        end
      end

      # add any unmapped instances
      logs_without_mapping = group_logs.map { |log| log.has_mapping? ? nil : log.id }.compact
      grouped = group_logs.where("id IN (?)", logs_without_mapping).group(:instance_type, :status).count
      last = nil
      grouped.each do |group|
        if !last || last && group[0][0] != last.instance_type
          instance = Instance.new(group[0][0], region, node_group, @project.platform, @project)
          instance.increase_count(InstanceLog::ON_STATUSES[@platform] == group[0][1] ? :on : :off, group[1])
          instances << last
          last = instance
        elsif last
          last.increase_count(InstanceLog::ON_STATUSES[@platform] == group[0][1] ? :on : :off, group[1])
        end
      end
      instances << last

      all_instances[node_group] = instances
    end
    all_instances
  end

  def set_future_changes(temp_change_request=nil)
    latest_instances(temp_change_request) unless @latest_instances

    scheduled_counts(false, temp_change_request).each do |date, group_details|
      group_details.each do |group, instance_types|
        instances = @latest_instances[group]
        instance_types.each do |instance_type, times_and_counts|
          instance = instances.find { |i| i.instance_type == instance_type }
          instance.add_future_counts({date => times_and_counts}) if instance
        end
      end
    end
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

  def scheduled_counts(exclude_request=nil, temp_change_request=nil)
    scheduled_counts = {}
    requests = @project.pending_one_off_and_repeat_requests
    if temp_change_request
      # When checking for an edited existing request, don't include twice
      if temp_change_request.actual_or_parent_id
        requests = requests.select { |request| request.actual_or_parent_id != temp_change_request.actual_or_parent_id}
      end
      requests = requests.to_a << temp_change_request.as_future_individual_requests
      requests = requests.flatten.compact.sort_by { |request| [request.date, request.time] }
    end
    requests.flatten.each do |request|
      next if exclude_request && (request.actual_or_parent_id == exclude_request.id)

      scheduled_counts[request.date] = {} if !scheduled_counts.has_key?(request.date)
      request.counts.each do |group, instances|
        min = request.counts_criteria == "min"
        if !scheduled_counts[request.date].has_key?(group)
          scheduled_counts[request.date][group] = {}
        end
        instances.each do |type, count|
          if scheduled_counts[request.date][group].has_key?(type)
            scheduled_counts[request.date][group][type][request.time] = {count: count, min: min}
          else
            scheduled_counts[request.date][group][type] = {request.time => {count: count, min: min}}
          end
        end
      end
    end
    scheduled_counts
  end

  def actual_counts(groups=nil, use_front_end_types=false)
    determine_counts(false, groups, use_front_end_types)
  end

  def actual_with_pending_counts
    determine_counts
  end

  # A lighterweight method of getting just the counts,
  # for when we don't need to know costs, future counts, etc.
  def determine_counts(include_pending=true, groups=nil, use_front_end_types=false)
    instances = @project.latest_instance_logs

    counts = {}
    instances.each do |instance|
      group = instance.compute_group
      next if groups && !groups.include?(group)

      type = use_front_end_types ? instance.front_end_instance_type : instance.instance_type
      status = include_pending ? instance.pending_status : instance.status
      value = InstanceLog::ON_STATUSES[instance.platform][status] ? 1 : 0
      if counts.has_key?(group)
        if counts[group].has_key?(type)
          counts[group][type] += value
        else
          counts[group][type] = value
        end
      else
        counts[group] = {type => value}
      end
    end
    counts
  end

  # Returns the number of active nodes and total number for each group
  def nodes_up
    {}.tap do |nodes|
      latest_instance_count.each do |group, instances|
        on = 0
        total = 0
        instances.each do |instance|
          next if instance.node_limit == 0
          on += instance.count[:on]
          total += on + instance.count[:off]
        end
        nodes[group] = {on: on, total: total}
      end
    end
  end
end
