require_relative "lib/github_discord_relay"

settings = GithubDiscordRelay::Settings.new
store = GithubDiscordRelay::Store.new(settings.database_path)
discord = GithubDiscordRelay::DiscordClient.new(settings.discord_token, store: store, settings: settings)
Thread.new { discord.start }

trap("TERM") { discord.stop; exit }
trap("INT") { discord.stop; exit }

run GithubDiscordRelay::App.new(settings: settings, store: store, discord: discord)
