class CrossrefOrcid < Agent
  # include common methods for Import
  include Importable

  def get_query_url(options={})
    offset = options[:offset].to_i
    rows = options[:rows].presence || job_batch_size
    from_date = options[:from_date].presence || (Time.zone.now.to_date - 1.day).iso8601
    until_date = options[:until_date].presence || Time.zone.now.to_date.iso8601

    filter = "has-orcid:true"
    filter += ",from-update-date:#{from_date}"
    filter += ",until-update-date:#{until_date}"

    params = { filter: filter, offset: offset, rows: rows }

    url + params.to_query
  end

  def get_total(options={})
    query_url = get_query_url(options.merge(rows: 0))
    result = get_result(query_url, options)
    result.fetch('message', {}).fetch('total-results', 0)
  end

  def queue_jobs(options={})
    return 0 unless active?

    unless options[:all]
      return 0 unless stale?
    end

    query_url = get_query_url(options.merge(rows: 0))
    result = get_result(query_url, options)
    total = result.fetch("message", {}).fetch("total-results", 0)

    if total > 0
      # walk through paginated results
      total = sample if sample.present?
      total_pages = (total.to_f / job_batch_size).ceil

      (0...total_pages).each do |page|
        options[:offset] = page * job_batch_size
        options[:rows] = sample if sample && sample < (page + 1) * job_batch_size
        AgentJob.set(queue: queue, wait_until: schedule_at).perform_later(self, options)
      end

      schedule_next_run
    end

    # return number of works queued
    total
  end

  def parse_data(result, options={})
    result = { error: "No hash returned." } unless result.is_a?(Hash)
    return [result] if result[:error]

    items = result.fetch('message', {}).fetch('items', nil)
    get_relations_with_contributors(items)
  end

  def get_relations_with_contributors(items)
    Array(items).reduce([]) do |sum, item|
      date_parts = item.fetch("issued", {}).fetch("date-parts", []).first
      year, month, day = date_parts[0], date_parts[1], date_parts[2]

      # use date indexed if date issued is in the future
      if year.nil? || Date.new(*date_parts) > Time.zone.now.to_date
        date_parts = item.fetch("indexed", {}).fetch("date-parts", []).first
        year, month, day = date_parts[0], date_parts[1], date_parts[2]
      end

      title = case item["title"].length
              when 0 then nil
              when 1 then item["title"][0]
              else item["title"][0].presence || item["title"][1]
              end

      if title.blank? && !TYPES_WITH_TITLE.include?(item["type"])
        title = item["container-title"][0].presence || "No title"
      end

      publisher_id = item.fetch("member", nil).to_s[30..-1]

      type = item.fetch("type", nil)
      type = CROSSREF_TYPE_TRANSLATIONS[type] if type
      doi = item.fetch("DOI", nil)

      obj = { "pid" => doi_as_url(doi),
               "author" => item.fetch("author", []),
               "title" => title,
               "container-title" => item.fetch("container-title", []).first,
               "issued" => { "date-parts" => [date_parts] },
               "DOI" => doi,
               "publisher_id" => publisher_id,
               "volume" => item.fetch("volume", nil),
               "issue" => item.fetch("issue", nil),
               "page" => item.fetch("page", nil),
               "type" => type,
               "tracked" => tracked }

      authors_with_orcid = item.fetch('author', []).select { |author| author["ORCID"].present? }
      sum += get_relations(obj, authors_with_orcid)
    end
  end

  def get_relations(obj, items)
    prefix = obj["DOI"][/^10\.\d{4,5}/]

    Array(items).reduce([]) do |sum, item|
      orcid = item.fetch('ORCID', nil)
      orcid = validate_orcid(orcid)

      return sum if orcid.nil?

      sum << { prefix: prefix,
               message_type: "contribution",
               relation: { "subj_id" => orcid_as_url(orcid),
                           "obj_id" => obj["pid"],
                           "source_id" => source_id,
                           "publisher_id" => obj["publisher_id"] },
               obj: obj }
    end
  end

  def get_events(items)
    Array(items).map do |item|
      pid = doi_as_url(item.fetch("DOI"))
      authors_with_orcid = item.fetch('author', []).select { |author| author["ORCID"].present? }

      { source_id: source_id,
        work_id: pid,
        total: authors_with_orcid.length,
        extra: authors_with_orcid }
    end
  end

  def config_fields
    [:url]
  end

  def url
    "http://api.crossref.org/works?"
  end
end
