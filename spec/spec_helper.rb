require "rack/test"
require "rspec"
require_relative "../lib/github_discord_relay"

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
