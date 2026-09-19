module GithubDiscordRelay
  module Formatter
    COMPONENTS_V2_FLAG = 1 << 15
    COMPONENT_TYPES = {
      action_row: 1,
      button: 2,
      select_menu: 3,
      user_select: 5,
      role_select: 6,
      mentionable_select: 7,
      channel_select: 8,
      section: 9,
      text_display: 10,
      image: 11,
      gallery: 12,
      attachment: 13,
      sep: 14,
      container: 17,
      # The rest are for modals
    }.freeze

    TITLES = {
      "push" => "Push",
      "pull_request" => "Pull request",
      "issues" => "Issue",
      "issue_comment" => "Issue comment",
      "release" => "Release",
      "workflow_run" => "Workflow run",
      "repository" => "Repository"
    }.freeze

    module_function

    def message(event_name, payload, relay_name: nil)
      repository = payload.fetch("repository", {})
      sender = payload.fetch("sender", {})
      title = TITLES.fetch(event_name, event_name.tr("_", " ").split.map(&:capitalize).join(" "))
      title = "#{title}: #{payload["action"]}" if payload["action"]
      url = payload["html_url"] || repository["html_url"]
      sender_name = sender.fetch("login", "GitHub")
      sender_text = sender["html_url"] ? "[#{sender_name}](#{sender["html_url"]})" : sender_name
      title_text = url ? "[#{title}](#{url})" : title
      repository_name = repository.fetch("full_name", "GitHub")
      metadata = [relay_name, sender_text, repository_name].compact.join(" | ")

      {
        flags: COMPONENTS_V2_FLAG,
        components: [
          {
            type: COMPONENT_TYPES[:container],
            accent_color: 0x5865F2,
            components: [
              {
                type: COMPONENT_TYPES[:text_display],
                content: "## #{title_text}\n#{description(event_name, payload)}\n\n#{metadata}"
              }
            ]
          }
        ]
      }
    end

    def description(event_name, payload)
      case event_name
      when "push"
        commits = payload.fetch("commits", [])
        ref = payload.fetch("ref", "").sub("refs/heads/", "")
        "#{commits.length} commit(s) pushed to `#{ref}`."
      when "pull_request", "issues"
        payload.fetch(event_name, {}).fetch("title", "GitHub activity")
      when "release"
        payload.fetch("release", {}).fetch("name", "Release activity")
      else
        payload.fetch("action", "GitHub activity").tr("_", " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end
