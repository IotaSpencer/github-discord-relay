module GithubDiscordRelay
  class App < Sinatra::Base
    configure do
      set :show_exceptions, false
    end

    def initialize(app = nil, settings: Settings.new, store: nil, discord: nil)
      super(app)
      @relay_settings = settings
      @store = store || Store.new(settings.database_path)
      @discord = discord || DiscordClient.new(settings.discord_token, store: @store, settings: settings)
    end

    before do
      content_type :json
    end

    get "/health" do
      { status: "ok" }.to_json
    end

    post "/admin/users" do
      require_admin!
      input = json_body
      name = input.fetch("name")
      halt 422, { error: "Invalid user name" }.to_json unless name.match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
      channel_id = Integer(input.fetch("channel_id"))
      gh_user = input["gh_user"]
      halt 422, { error: "Invalid gh_user" }.to_json unless gh_user.nil? || gh_user.match?(/\A[^\s]{1,64}\z/)
      token, user = @store.create_user(name, channel_id, gh_user: gh_user)
      user_response(user, token)
    rescue Sequel::UniqueConstraintViolation
      halt 409, { error: "User already exists" }.to_json
    rescue KeyError, ArgumentError
      halt 422, { error: "name and channel_id are required" }.to_json
    end

    get "/admin/users" do
      require_admin!
      @store.list_users.map { |user| user_response(user) }.to_json
    end

    post "/admin/users/:name/:operation" do
      require_admin!
      operation = params["operation"]
      halt 404, { error: "Unknown operation" }.to_json unless %w[enable disable].include?(operation)
      active = operation == "enable"
      halt 404, { error: "User not found" }.to_json unless @store.set_active(params["name"], active)
      user_response(@store.find(params["name"])).to_json
    end

    post "/hooks/:token/components" do
      user = @store.find_by_token(params["token"])
      halt 401, { error: "Invalid or disabled webhook" }.to_json unless user
      payload = JSON.parse(request.body.read)
      halt 403, { error: "gh_user is not authorized for this webhook" }.to_json unless authorized_custom_post?(user, payload["gh_user"])
      halt 422, { error: "components must be an array" }.to_json unless payload["components"].is_a?(Array)

      @discord.relay_components(user, payload["components"])
      { status: "relayed" }.to_json
    rescue JSON::ParserError
      halt 400, { error: "Request body must be valid JSON" }.to_json
    end

    post "/hooks/:token" do
      user = @store.find_by_token(params["token"])
      halt 401, { error: "Invalid or disabled webhook" }.to_json unless user
      body = request.body.read
      halt 401, { error: "Invalid GitHub signature" }.to_json if @relay_settings.github_webhook_secret && !valid_signature?(body)
      payload = JSON.parse(body)
      @discord.relay(user, request.env.fetch("HTTP_X_GITHUB_EVENT", "unknown"), payload)
      { status: "relayed", name: user.name }.to_json
    rescue JSON::ParserError
      halt 400, { error: "Request body must be valid JSON" }.to_json
    end

    private

    def json_body
      JSON.parse(request.body.read)
    end

    def require_admin!
      expected = "Bearer #{@relay_settings.admin_token}"
      provided = request.env["HTTP_AUTHORIZATION"].to_s
      halt 401, { error: "Invalid admin token" }.to_json unless secure_compare(expected, provided)
    end

    def secure_compare(left, right)
      return false unless left.bytesize == right.bytesize
      Rack::Utils.secure_compare(left, right)
    end

    def valid_signature?(body)
      signature = request.env["HTTP_X_HUB_SIGNATURE_256"].to_s
      return false unless signature.start_with?("sha256=")
      expected = OpenSSL::HMAC.hexdigest("SHA256", @relay_settings.github_webhook_secret, body)
      secure_compare(expected, signature.delete_prefix("sha256="))
    end

    def authorized_custom_post?(user, gh_user)
      user.gh_user && gh_user && secure_compare(user.gh_user, gh_user)
    end

    def user_response(user, token = nil)
      response = { name: user.name, channel_id: user.channel_id, active: user.active }
      response[:gh_user] = user.gh_user if user.gh_user
      if token
        response[:webhook_url] = "#{@relay_settings.public_base_url.chomp("/")}/hooks/#{token}"
        response[:token] = token
      end
      response
    end
  end
end
