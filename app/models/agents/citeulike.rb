class Citeulike < Agent
  def request_options
    { content_type: 'xml' }
  end

  def get_query_url(options={})
    work = Work.where(id: options.fetch(:work_id, nil)).first
    return {} unless work.present? && work.doi.present?

    url % { doi: work.doi_escaped }
  end

  def get_provenance_url(options={})
    work = Work.where(id: options.fetch(:work_id, nil)).first
    return nil unless provenance_url.present? && work.present? && work.doi.present?

    provenance_url % { doi: work.doi_escaped }
  end

  def get_relations_with_related_works(result, work)
    related_works = result["posts"] && result["posts"].is_a?(Hash) && result.fetch("posts", {}).fetch("post", [])
    related_works = [related_works] if related_works.is_a?(Hash)
    related_works ||= nil
    provenance_url = get_provenance_url(work_id: work.id)

    Array(related_works).map do |item|
      timestamp = get_iso8601_from_time(item.fetch("post_time", nil))
      citeulike_url = item.fetch("link", {}).fetch("url", nil)
      path = URI.split(citeulike_url)[5].split("/")
      account = path[1]
      author = path[2]
      citeulike_url = "http://www.citeulike.org/" + path[1..2].join("/")

      { prefix: work.prefix,
        relation: { "subj_id" => citeulike_url,
                    "obj_id" => work.pid,
                    "relation_type_id" => "bookmarks",
                    "source_id" => name,
                    "occurred_at" => timestamp,
                    "provenance_url" => provenance_url },
        subj: { "pid" => citeulike_url,
                "author" => get_authors([author]),
                "title" => "CiteULike bookmarks for #{account} #{author}",
                "container-title" => "CiteULike",
                "issued" => timestamp,
                "URL" => url,
                "type" => "entry",
                "tracked" => tracked } }
    end
  end

  def config_fields
    [:url, :provenance_url]
  end

  def url
    "http://www.citeulike.org/api/posts/for/doi/%{doi}"
  end

  def provenance_url
    "http://www.citeulike.org/doi/%{doi}"
  end

  def rate_limiting
    config.rate_limiting || 2000
  end

  def queue
    config.queue || "low"
  end
end
