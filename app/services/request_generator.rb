require 'uri'
require 'net/http'
require 'json'

# headers and query should both be hashes. body should be a string.
def http_request(uri:, headers: {}, query: {}, body: )
  uri = URI(uri)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Get.new(uri.request_uri)
  headers.each do |key, value|
    request[key] = value
  end
  request.set_form_data(query)
  request.body = body

  http.request(request).body
end
