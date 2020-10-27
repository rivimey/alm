class Mendeley < Agent
  def request_options
    { bearer: access_token }
  end

  def parse_data(result, options={})
    return [result] if result[:error].is_a?(String)

    result = result.fetch("data", []).first || {}

    work = Work.where(id: options.fetch(:work_id, nil)).first
    return [{ error: "Resource not found.", status: 404 }] unless work.present?

    readers = result.fetch("reader_count", 0)
    groups = result.fetch("group_count", 0)
    subj_id = result.fetch("link", "https://www.mendeley.com")

    relations = []
    if readers > 0
      relations << { prefix: work.prefix,
                     relation: { "subj_id" => subj_id,
                                 "obj_id" => work.pid,
                                 "relation_type_id" => "bookmarks",
                                 "total" => readers,
                                 "source_id" => source_id },
                     subj: { "pid" => subj_id,
                             "URL" => subj_id,
                             "title" => "Mendeley",
                             "type" => "webpage",
                             "issued" => "2012-05-15T16:40:23Z" }}
    end

    if groups > 0
      relations << { prefix: work.prefix,
                     relation: { "subj_id" => subj_id,
                                 "obj_id" => work.pid,
                                 "relation_type_id" => "likes",
                                 "total" => groups,
                                 "source_id" => source_id },
                     subj: { "pid" => subj_id,
                             "URL" => subj_id,
                             "title" => "Mendeley",
                             "type" => "webpage",
                             "issued" => "2012-05-15T16:40:23Z" }}
    end

    relations
  end

  def get_query_url(options={})
    work = Work.where(id: options.fetch(:work_id, nil)).first

    # First check that we have a valid OAuth2 access token, and a refreshed uuid
    return {} unless work.present? && (work.doi.present? || work.pmid.present? || work.scp.present?)
    fail ArgumentError, "No Mendeley access token." unless get_access_token

    if work.doi.present?
      query_string = "doi=#{work.doi}"
    elsif work.pmid.present?
      query_string = "pmid=#{work.pmid}"
    else
      query_string = "scopus=#{work.scp}"
    end

    url % { :query_string => query_string }
  end

  def get_access_token(options={})
    # Check whether access token is valid for at least another 5 minutes
    return true if access_token.present? && (Time.zone.now + 5.minutes < expires_at.to_time.utc)

    # Otherwise get new access token
    result = get_result(authentication_url, options.merge(
      username: client_id,
      password: client_secret,
      data: "grant_type=client_credentials&scope=all",
      source_id: source_id,
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }))

    if result.present? && result["access_token"] && result["expires_in"]
      config.expires_at = Time.zone.now + result["expires_in"].seconds
      config.access_token = result["access_token"]
      save
    else
      false
    end
  end

  # Format Mendeley events for all works as csv
  def to_csv(options = {})
    service_url = "#{ENV['COUCHDB_URL']}/_design/reports/_view/mendeley"

    result = get_result(service_url, options.merge(timeout: 1800))
    if result.blank? || result["rows"].blank?
      message = "CouchDB report for Mendeley could not be retrieved."
      Notification.where(message: message).where(unresolved: true).first_or_create(
        exception: "",
        class_name: "Faraday::ResourceNotFound",
        status: 404,
        source_id: source_id,
        level: Notification::FATAL)
      return nil
    end

    CSV.generate do |csv|
      csv << ["pid_type", "pid", "readers", "groups", "total"]
      result["rows"].each { |row| csv << ["doi", row["key"], row["value"]["readers"], row["value"]["groups"], row["value"]["readers"] + row["value"]["groups"]] }
    end
  end

  def config_fields
    [:url, :authentication_url, :client_id, :client_secret, :access_token, :expires_at]
  end

  def url
    "https://api.mendeley.com/catalog?%{query_string}&view=stats"
  end

  def authentication_url
    "https://api.mendeley.com/oauth/token"
  end
end
