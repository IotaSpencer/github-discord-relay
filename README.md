# GitHub Discord Relay

A Sinatra and discordrb service that forwards GitHub webhook events to Discord. Each relay user gets a separate URL token, and an administrator can disable a user's token without affecting anyone else.

## Setup

1. Install Ruby 3.1+ and Bundler.
2. Create a Discord bot, enable the required intents, and invite it with both the `bot` and `applications.commands` scopes to the server(s) where it should post.
3. Copy `.env.example` to `.env` and fill in `DISCORD_TOKEN`, `ADMIN_TOKEN`, and `PUBLIC_BASE_URL`.
4. Install the project:

  ```bash
  bundle install
   ```

5. Start the service:

   ```bash
  bundle exec ruby bin/server
   ```

## Managing relay users

Create a user and receive their one-time webhook URL:

```bash
curl -X POST http://localhost:8000/admin/users \
  -H 'Authorization: Bearer YOUR_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"name":"alice","channel_id":123456789012345678}'
```

The response contains a `webhook_url` and raw token. Store the token securely; it is not returned again. Configure that URL as a GitHub repository or organization webhook with content type `application/json`.

List users:

```bash
curl http://localhost:8000/admin/users \
  -H 'Authorization: Bearer YOUR_ADMIN_TOKEN'
```

Disable a user immediately:

```bash
curl -X POST http://localhost:8000/admin/users/alice/disable \
  -H 'Authorization: Bearer YOUR_ADMIN_TOKEN'
```

Re-enable the existing user:

```bash
curl -X POST http://localhost:8000/admin/users/alice/enable \
  -H 'Authorization: Bearer YOUR_ADMIN_TOKEN'
```

The webhook endpoint accepts `POST /hooks/{token}` and returns `401` for unknown or disabled tokens. If `GITHUB_WEBHOOK_SECRET` is set, GitHub's `X-Hub-Signature-256` header is also required. Run tests with `bundle exec rake`.

To post a custom Discord component-v2 announcement, configure the relay user's `gh_user` value when creating it, then call the components endpoint with the matching value:

```bash
curl -X POST http://localhost:8000/hooks/YOUR_WEBHOOK_TOKEN/components \
  -H 'Content-Type: application/json' \
  -d '{"gh_user":"octocat","components":[{"type":10,"content":"## Maintenance\nThe service will be unavailable briefly."}]}'
```

The webhook token is validated against `relay_users.token_hash`; `gh_user` is an additional permission check. The supplied component layout is sent as Discord components with the Component V2 flag. The endpoint returns `401` when either authorization value is invalid and `422` when `components` is not an array.

## Discord management commands

Set `ADMIN_GUILD_ID`, `ADMIN_CHANNEL_ID`, and `ADMIN_USER_IDS` in `.env`. The bot registers these guild-scoped slash commands:

- `/relay_create name:<name> channel_id:<discord-channel-id>` creates a user and privately returns its one-time webhook URL.
- `/relay_list` lists users and their enabled/disabled state.
- `/relay_disable name:<name>` disables a user's webhook immediately.
- `/relay_enable name:<name>` re-enables a disabled webhook.

Commands only work in the configured guild and admin channel, and only for users listed in `ADMIN_USER_IDS`. Responses are ephemeral, so tokens and user data are not posted into the channel history.

## Security notes

- User tokens are stored as SHA-256 hashes, never plaintext.
- Use HTTPS in production and keep `.env` out of source control.
- `ADMIN_TOKEN` controls all user management, so make it long and random.
- Discord channel permissions are still enforced by Discord; the bot needs permission to send messages in each configured channel.
