class AuditLogList
  ACTION_LOG_PAGE_LENGTH = 5
  LOG_TYPES = {"action_logs" => "Action logs",
               "change_requests" => "Change requests",
               "change_request_audit_logs" => "CR audit logs",
               "config_logs" => "Config logs",
               "funds_transfer_requests" => "Funds transfers"
              }
  POSSIBLE_STATUSES = %w[completed cancelled failed pending started submitted]

  attr_reader :filters

  def initialize(project, filters=nil)
    @project = project
    @filters = remove_blanks(filters)
  end

  def types
    filters["types"] || LOG_TYPES.keys
  end

  def users
    filters["users"]
  end

  def start_date
    filters["start_date"]
  end

  def end_date
    filters["end_date"]
  end

  def statuses
    filters["statuses"]
  end

  def groups
    filters["groups"]
  end

  def filtered_logs
    if !@logs
      @logs = []
      if !@filters
        @logs = all_logs
      else
        types.each do |type|
          # config logs are immediately completed so don't have a stored status field
          if type == "config_logs" && statuses && !statuses.include?("completed")
            next
          end

          # config logs and funds requests do not have a compute group
          next if groups && (type == "config_logs" || type == "funds_transfer_requests")

          matching_of_type = @project.send(type)
          # assume we get usernames
          if users
            user_ids = User.where("username in (?)", users).pluck(:id)
            includes_automated = users.include?("automated")
            query = "user_id IN (?) #{"OR user_id IS NULL" if includes_automated}"
            matching_of_type = matching_of_type.where(query, user_ids)
          end

          if start_date || end_date
            matching_of_type = matching_of_type.where("date >= ?", start_date) if start_date
            matching_of_type = matching_of_type.where("date <= ?", end_date) if end_date
          end

          if statuses
            if type != "config_logs" && type != "change_request_audit_logs"
              matching_of_type = matching_of_type.where("status in (?)", statuses)
            elsif !statuses.include?("completed")
              matching_of_type = []
            end
          end

          # below is not an active record query so needs to be last
          if groups
            matching_of_type = matching_of_type.select do |log|
              matches = false
              groups.each do |group|
                matches = log.includes_group?(group)
                break if matches
              end
              matches
            end
          end
          @logs.concat(matching_of_type)
        end
      end
      @logs.flatten.compact
      @logs = @logs.sort_by { |log| [log.created_at, log.id] }.reverse
    end
    @logs
  end

  def more_logs?
    filtered_logs.length > ACTION_LOG_PAGE_LENGTH
  end

  def first_logs
    filtered_logs.first(ACTION_LOG_PAGE_LENGTH)
  end

  def next_logs(current_log_count, latest_timestamp)
    # Need to convert times to ints when comparing, as otherwise equality may
    # not be found due to very small differences (in db has greated level
    # of precision than is captured in a time previously converted to a string)
    logs = filtered_logs.select {|log| log.created_at.to_i <= latest_timestamp.to_i}
    logs = logs.sort_by { |log| [log.created_at, log.id] }
    logs.pop(current_log_count)
    logs.reverse!

    more_logs = logs.length > ACTION_LOG_PAGE_LENGTH
    return logs.first([logs.length, ACTION_LOG_PAGE_LENGTH].min), more_logs
  end

  def all_logs
    @logs ||= LOG_TYPES.keys.map {|type| @project.send(type)}.flatten.compact.sort_by(&:created_at).reverse
  end

  private

  def remove_blanks(filters_hash)
    filters_hash.select {|k,v| !v.blank? }
  end
end
