require "fileutils"
require "tmpdir"

RSpec.describe GithubDiscordRelay::App do
  FakeSettings = Struct.new(:admin_token, :public_base_url, :database_path, :github_webhook_secret)
  FakeDiscord = Struct.new(:events) do
    def relay(user, event_name, payload)
      events << [user, event_name, payload]
    end
  end

  before do
    @tmpdir = Dir.mktmpdir
    @discord = FakeDiscord.new([])
  end

  after { FileUtils.remove_entry(@tmpdir) }

  it "creates, lists, and disables an individual user" do
    post "/admin/users", { name: "alice", channel_id: 123 }.to_json, "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer admin-token"
    expect(last_response.status).to eq(200)
    created = JSON.parse(last_response.body)
    expect(created["webhook_url"]).to start_with("https://relay.example/hooks/")

    get "/admin/users", {}, "HTTP_AUTHORIZATION" => "Bearer admin-token"
    expect(JSON.parse(last_response.body)).to eq([{ "name" => "alice", "channel_id" => 123, "active" => true }])

    post "/admin/users/alice/disable", {}, "HTTP_AUTHORIZATION" => "Bearer admin-token"
    expect(JSON.parse(last_response.body)["active"]).to be(false)
    post "/hooks/#{created["token"]}", {}.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(401)
  end

  it "relays a valid active webhook" do
    post "/admin/users", { name: "alice", channel_id: 123 }.to_json, "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer admin-token"
    token = JSON.parse(last_response.body).fetch("token")
    post "/hooks/#{token}", { action: "opened" }.to_json, "CONTENT_TYPE" => "application/json", "HTTP_X_GITHUB_EVENT" => "issues"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)["name"]).to eq("alice")
    expect(@discord.events.first[1]).to eq("issues")
    expect(@discord.events.first[0].name).to eq("alice")
  end

  def app
    settings = FakeSettings.new("admin-token", "https://relay.example", File.join(@tmpdir, "relay.sqlite3"), nil)
    GithubDiscordRelay::App.new(settings: settings, discord: @discord)
  end
end
