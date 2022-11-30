class ComputeGroupConfigLog < ConfigLog

  def full_details(details)
    full_details = {}
    details.each do |group, changes|
      full_details[group] = {}
      changes.each do |attribute, values|
        next if attribute == "updated_at" || values.empty?
        if attribute == "types"
          full_details[group]["types"] = {}
          values.each do |type, changes|
            next if attribute == "updated_at" || changes.empty?

            full_details[group]["types"][type] = {"priority" => {"from" => changes["priority"][0], "to" => changes["priority"][1] }}
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
      html << "<strong>#{group}</strong><br>"
      details.each do |attribute, values|
        if attribute == "types"
          values.each do |type, attributes|
            html << "<em>#{type} priority: <strike>#{attributes["priority"]["from"]}</strike> #{attributes["priority"]["to"]}<br>"
          end
        else
          html << "#{attribute}: <strike>#{values["from"]}</strike> #{values["to"]}<br>"
        end
      end
    end
    html
  end

end
