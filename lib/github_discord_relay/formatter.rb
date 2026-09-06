module GithubDiscordRelay
  module Formatter
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

    def embed(event_name, payload)
      repository = payload.fetch("repository", {})
      sender = payload.fetch("sender", {})
      title = TITLES.fetch(event_name, event_name.tr("_", " ").split.map(&:capitalize).join(" "))
      title = "#{title}: #{payload["action"]}" if payload["action"]

      {
        title: title,
        url: payload["html_url"] || repository["html_url"],
        description: description(event_name, payload),
        color: 0x5865F2,
        author: { name: sender.fetch("login", "GitHub"), url: sender["html_url"] },
        footer: { text: repository.fetch("full_name", "GitHub") }
      }.compact
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
