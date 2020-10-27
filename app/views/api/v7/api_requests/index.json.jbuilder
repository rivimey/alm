json.meta do
  json.status "ok"
  json.set! :"message-type", "api_request-list"
  json.set! :"message-version", "v7"
  json.total @api_requests.total_entries
  json.total_pages @api_requests.per_page > 0 ? @api_requests.total_pages : 1
  json.page @api_requests.total_entries > 0 ? @api_requests.current_page : 1
end

json.api_requests @api_requests do |api_request|
  json.(api_request, :id, :api_key, :info, :source, :ids, :db_duration, :view_duration, :duration, :timestamp)
end
