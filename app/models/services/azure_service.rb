require 'httparty'
require_relative '../azure_project'

class AzureService
  MAX_API_ATTEMPTS = 3
  DEFAULT_TIMEOUT = 180

  def initialize(project)
    @project = project
  end
end

class AzureApiError < StandardError
  attr_accessor :error_messages
  def initialize(msg)
    @error_messages = []
    super(msg)
  end
end
