module ApplicationHelper
  def repo_web_path(repo)
    "/#{repo.owner.username}/#{repo.name}"
  end

  def repo_push_label(repo)
    return "Not pushed yet" if repo.last_pushed_at.blank?

    "Updated #{time_ago_in_words(repo.last_pushed_at)} ago"
  end
end
