class ComputeGroupConfigLog < ConfigLog

  def full_details(details)
    full_details = {}
    details.each do |group, changes|
      full_details[group] = {}
      changes.each do |attribute, values|
        next unless group_tracked_attributes.include?(attribute) && !values.empty?

        if attribute == "types"
          full_details[group]["types"] = {}
          values.each do |type, changes|
            next if changes.empty?

            full_details[group]["types"][type] = {}
            instance_type_tracked_attributes.each do |attribute|
              next unless changes[attribute]

              full_details[group]["types"][type][attribute] = { "from" => changes[attribute][0], "to" => changes[attribute][1] }
            end
          end
          full_details[group].delete("types") if full_details[group]["types"].empty?
        else
          full_details[group][attribute] = {"from" => values[0], "to" => values[1] }
        end
      end
      full_details.delete(group) if full_details[group].empty?
    end
    full_details
  end

  def card_details
    html = ""
    config_changes.each do |group, details|
      html << "<strong>#{group}</strong>#{" (new)" if details["id"]}<br>"
      details.each do |attribute, values|
        if attribute == "types"
          values.each do |type, attributes|
            customer_facing_type = InstanceMapping.customer_facing_type(project.platform, type)
            html << "<em>#{customer_facing_type}</em>: "
            html << attributes.map {|k, v| "#{k.gsub("_", " ")} <strike>#{v["from"]}</strike> #{v["to"]}" if k != "id" }.compact.join(", ")
            html << " (new)" if attributes["id"]
            html << "<br>"
          end
        elsif attribute != "id"
          html << "#{attribute.gsub("_", " ")}: <strike>#{values["from"]}</strike> #{values["to"]}<br>"
        end
      end
      html << "<br>"
    end
    html
  end

  private

  def group_tracked_attributes
    %w(colour storage_colour priority types archived_date id)
  end

  def instance_type_tracked_attributes
    %w(priority limit archived_date id)
  end

end
