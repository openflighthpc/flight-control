class AzureInstanceManager < AzureService

  def update_instance_statuses(action, resource_group, node_names, verbose=false)
    command = action == "on" ? "start" : "deallocate"
    node_names.each do |node|
      uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/resourceGroups/#{resource_group}/providers/Microsoft.Compute/virtualMachines/#{node}/#{command}"
      query = {
        'api-version': '2020-12-01',
      }
      attempt = 0
      error = AzureApiError.new("Timeout error querying compute nodes for project"\
                                "#{@project.name}. All #{MAX_API_ATTEMPTS} attempts timed out.")
      begin
        @project.authoriser.refresh_auth_token
        attempt += 1
        response = HTTParty.post(
          uri,
          query: query,
          headers: {"Authorization": "Bearer #{@project.bearer_token}",
                    "Accept" => "application/json"
                   },
          timeout: DEFAULT_TIMEOUT
        )
        if response.success?
          # do nothing - the API doesn't return anything
        elsif response.code == 504
          raise Net::ReadTimeout
        else
          raise AzureApiError.new("Error querying compute nodes for project #{@project.name}."\
                                  "\nError code #{response.code}.\n#{response if @verbose}")
        end
      rescue Net::ReadTimeout
        msg = "Attempt #{attempt}: Request timed out.\n"
        if response
          msg << "Error code #{response.code}.\n#{response if @verbose}\n"
        end
        error.error_messages.append(msg)
        if attempt < MAX_API_ATTEMPTS
          retry
        else
          raise error
        end
      end 
    end
  end
end
