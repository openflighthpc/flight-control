require 'uri'
require 'net/http'
require 'json'

# headers and query should both be hashes. body should be a string.
def http_request(uri:, request_type: "get", headers: {}, query: {}, body: nil )
  uri = URI(uri)
  http = Net::HTTP.new(uri.host, uri.port)

  uri.query = URI.encode_www_form(query)
  request = request_type=="get" ? Net::HTTP::Get.new(uri.request_uri) : Net::HTTP::Post.new(uri.request_uri)
  headers.each do |key, value|
    request[key] = value
  end
  request.body = body

  http.request(request)
end
