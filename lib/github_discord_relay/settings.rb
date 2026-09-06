module GithubDiscordRelay
  class Settings
    attr_reader :discord_token, :admin_token, :public_base_url, :database_path,
          :github_webhook_secret, :port, :admin_guild_id, :admin_channel_id,
          :admin_user_ids

    def initialize(env = ENV)
      @discord_token = env.fetch("DISCORD_TOKEN")
      @admin_token = env.fetch("ADMIN_TOKEN")
      @public_base_url = env.fetch("PUBLIC_BASE_URL", "http://localhost:9292")
      @database_path = env.fetch("DATABASE_PATH", "./relay.sqlite3")
      @github_webhook_secret = env["GITHUB_WEBHOOK_SECRET"]
      @port = Integer(env.fetch("PORT", "9292"))
      @admin_guild_id = Integer(env.fetch("ADMIN_GUILD_ID"))
      @admin_channel_id = Integer(env.fetch("ADMIN_CHANNEL_ID"))
      @admin_user_ids = env.fetch("ADMIN_USER_IDS").split(",").map { |id| Integer(id.strip) }
    end
  end
end
