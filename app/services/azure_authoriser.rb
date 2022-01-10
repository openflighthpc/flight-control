require_relative 'azure_service'

class AzureAuthoriser < AzureService
  def refresh_auth_token
    if !@project.bearer_expiry || Time.now.to_i > @project.bearer_expiry.to_i
      update_bearer_token
    end
  end

  def update_bearer_token
    attempt = 0
    error = AzureApiError.new("Timeout error obtaining new authorization token for project"\
                              "#{@project.name}. All #{MAX_API_ATTEMPTS} attempts timed out.")
    begin
      attempt += 1
      response = HTTParty.post(
        "https://login.microsoftonline.com/#{@project.tenant_id}/oauth2/token",
        body: URI.encode_www_form(
          client_id: @project.azure_client_id,
          client_secret: @project.client_secret,
          resource: 'https://management.azure.com',
          grant_type: 'client_credentials',
        ),
        headers: {
          'Accept' => 'application/json'
        },
        timeout: DEFAULT_TIMEOUT
      )
      if response.success?
        body = JSON.parse(response.body)
        @project.bearer_token = body['access_token']
        @project.bearer_expiry = body['expires_on']
        @project.save
      elsif response.code == 504
        raise Net::ReadTimeout
      else
        raise AzureApiError.new("Error obtaining new authorization token for project #{@project.name}.\nError code #{response.code}\n#{response if @verbose}")
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
