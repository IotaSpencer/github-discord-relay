RSpec.describe GithubDiscordRelay::Formatter do
  it "formats webhook events as Discord component v2 messages" do
    message = described_class.message(
      "issues",
      {
        "action" => "opened",
        "html_url" => "https://github.com/example/project/issues/1",
        "issues" => { "title" => "An issue" },
        "repository" => { "full_name" => "example/project" },
        "sender" => { "login" => "octocat", "html_url" => "https://github.com/octocat" }
      }
    )

    expect(message[:flags]).to eq(1 << 15)
    expect(message[:components]).to eq(
      [
        {
          type: 17,
          accent_color: 0x5865F2,
          components: [
            {
              type: 10,
              content: "## [Issue: opened](https://github.com/example/project/issues/1)\nAn issue\n\n[octocat](https://github.com/octocat) | example/project"
            }
          ]
        }
      ]
    )
  end
end