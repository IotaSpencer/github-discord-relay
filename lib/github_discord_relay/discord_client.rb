require "discordrb"

module GithubDiscordRelay
  class DiscordClient
    def initialize(token, store:, settings:)
      @bot = Discordrb::Bot.new(token: token, intents: [:server_messages, :server_members])
      @store = store
      @settings = settings
      register_management_commands
    end

    def start
      @bot.run(true)
    end

    def stop
      @bot.stop
    end

    def relay(user, event_name, payload)
      @bot.send_message(user.channel_id, nil, false, Formatter.embed(event_name, payload))
    end

    private

    def register_management_commands
      register_create_command
      register_list_command
      register_state_command(:relay_enable, "Enable a relay user", true)
      register_state_command(:relay_disable, "Disable a relay user", false)
    end

    def register_create_command
      @bot.register_application_command(:relay_create, "Create a GitHub relay user", server_id: @settings.admin_guild_id) do |command|
        command.string(:name, "A short unique user name", required: true)
        command.string(:channel_id, "Discord channel ID for GitHub messages", required: true)
      end

      @bot.application_command(:relay_create) do |event|
        next unless authorized_admin?(event)

        name = option(event, :name)
        channel_id = Integer(option(event, :channel_id))
        token, user = @store.create_user(name, channel_id)
        event.respond(
          content: "Created `#{user.name}` for channel `#{user.channel_id}`.\nWebhook URL: `#{webhook_url(token)}`\nStore this URL securely; it will not be shown again.",
          ephemeral: true
        )
      rescue Sequel::UniqueConstraintViolation
        event.respond(content: "A relay user with that name already exists.", ephemeral: true)
      rescue ArgumentError, KeyError
        event.respond(content: "The channel ID must be a valid Discord channel ID.", ephemeral: true)
      end
    end

    def register_list_command
      @bot.register_application_command(:relay_list, "List GitHub relay users", server_id: @settings.admin_guild_id)
      @bot.application_command(:relay_list) do |event|
        next unless authorized_admin?(event)

        users = @store.list_users
        lines = users.map { |user| "- `#{user.name}` | channel `#{user.channel_id}` | #{user.active ? "enabled" : "disabled"}" }
        event.respond(content: users.empty? ? "No relay users configured." : lines.join("\n"), ephemeral: true)
      end
    end

    def register_state_command(name, description, active)
      @bot.register_application_command(name, description, server_id: @settings.admin_guild_id) do |command|
        command.string(:name, "Relay user name", required: true)
      end

      @bot.application_command(name) do |event|
        next unless authorized_admin?(event)

        user_name = option(event, :name)
        halt_message = active ? "enabled" : "disabled"
        unless @store.set_active(user_name, active)
          event.respond(content: "Relay user `#{user_name}` was not found.", ephemeral: true)
          next
        end
        event.respond(content: "Relay user `#{user_name}` is now #{halt_message}.", ephemeral: true)
      end
    end

    def authorized_admin?(event)
      return true if event.server && event.server.id == @settings.admin_guild_id &&
                     event.channel.id == @settings.admin_channel_id &&
                     @settings.admin_user_ids.include?(event.user.id)

      event.respond(content: "This command is only available to configured administrators in the admin channel.", ephemeral: true)
      false
    end

    def webhook_url(token)
      "#{@settings.public_base_url.chomp("/")}/hooks/#{token}"
    end

    def option(event, name)
      event.options[name] || event.options[name.to_s]
    end
  end
end
