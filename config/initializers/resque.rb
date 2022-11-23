# The dokku-redis plugin sets an application's REDIS_URL to have a username and password, but this
# causes issues, in part due to us using an old version of dokku-redis. To get around
# this, remove the username from the url.
#
# This may be fragile if deployed in different circumstances.
redis_url = ENV["REDIS_URL"]
if redis_url
  if redis_url.count(":") > 2
    redis_url = redis_url.gsub(/(?<=\/{2})(.*?)*:/, '')
  end
  Resque.redis = redis_url
else
  Resque.redis = 'localhost:6379'
end
