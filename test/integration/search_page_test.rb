require "test_helper"

class SearchPageTest < ActionDispatch::IntegrationTest
  setup do
    Star.delete_all
    Repo.delete_all
    User.delete_all
  end

  test "renders ranked search results for a natural-language query" do
    owner = User.create!(username: "hazel")
    best = Repo.create!(
      owner: owner,
      name: "slack-notify",
      description: "Posts to Slack",
      tags: ["slack", "notifications"],
      path: "/tmp/lore-repos/hazel/slack-notify.git",
      embedding: [1.0, 0.0],
      last_pushed_at: Time.zone.parse("2026-03-28 16:20:00 UTC")
    )
    Repo.create!(
      owner: owner,
      name: "send-email",
      description: "Sends email",
      tags: ["email"],
      path: "/tmp/lore-repos/hazel/send-email.git",
      embedding: [0.0, 1.0]
    )
    Star.create!(user: User.create!(username: "agent"), repo: best)

    with_stubbed_embedding([1.0, 0.0]) do
      get search_path, params: { q: "send slack notification" }
    end

    assert_response :success
    assert_select "input[value='send slack notification']"
    assert_select ".result-card", minimum: 2
    assert_includes response.body, "Similarity 1.0000"
    assert_operator response.body.index("hazel/slack-notify"), :<, response.body.index("hazel/send-email")
  end

  test "renders an intentional prompt when no query is provided" do
    get search_path

    assert_response :success
    assert_select ".search-message", text: /Search Lore by outcome\./
  end

  test "renders a friendly empty state when no repos match" do
    owner = User.create!(username: "hazel")
    Repo.create!(owner: owner, name: "no-embedding", description: "No embedding", tags: [], path: "/tmp/lore-repos/hazel/no-embedding.git")

    with_stubbed_embedding([1.0, 0.0]) do
      get search_path, params: { q: "send slack notification" }
    end

    assert_response :success
    assert_select ".search-message", text: /No repos matched\./
  end

  test "renders a service message when embeddings fail" do
    with_stubbed_embedding_error("OPENAI_API_KEY is not configured") do
      get search_path, params: { q: "send slack notification" }
    end

    assert_response :service_unavailable
    assert_select ".search-message", text: /Search is unavailable\./
  end

  private

  def with_stubbed_embedding(result)
    original = Lore::Embeddings.method(:embed)
    Lore::Embeddings.singleton_class.define_method(:embed) { |_query| result }
    yield
  ensure
    Lore::Embeddings.singleton_class.define_method(:embed, original)
  end

  def with_stubbed_embedding_error(message)
    original = Lore::Embeddings.method(:embed)
    Lore::Embeddings.singleton_class.define_method(:embed) { |_query| raise Lore::Embeddings::Error, message }
    yield
  ensure
    Lore::Embeddings.singleton_class.define_method(:embed, original)
  end
end
