json.meta do
  json.status @status || "ok"
  json.set! :"message-type", "deposit"
  json.set! :"message-version", "6.0.0"
end

json.deposit do
  json.cache! ['v6', @deposit], skip_digest: true do
    json.(@deposit, :id, :state, :message_type, :message_action, :source_token, :callback, :prefix, :subj_id, :obj_id, :relation_type_id, :source_id, :publisher_id, :total, :occured_at, :timestamp, :subj, :obj)
  end
end
