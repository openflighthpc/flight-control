class AzureInstanceManager < AzureService

  def update_instance_statuses(action, resource_group, node_names, verbose=false)
    node_names.each do |node_name|
      command = action == "on" ? "start-instance" : "stop-instance"
      response = http_request(uri: 'http://0.0.0.0:4567/providers/azure/#{command}',
                              headers: {"Project-Credentials" => {"resource_group": resource_group}.inspect},
                              body: { "node_name" => node_name }.to_json
                             )
      case response.code
      when 200
        #Instance state set successfully
      when 401
        raise 'Credentials missing or incorrect'
      when 404
        raise 'Provider #{creds["provider"]} and/or instance #{instance_id} not found'
      when 500
        raise 'Internal error in Control API'
      end
    end
  end
end
