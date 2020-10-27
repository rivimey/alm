xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    if @work.nil?
      xml.title "Lagotto: work not found"
      xml.link root_url
    else
      xml.title "Lagotto: references for work #{@work.pid}"
      xml.link @work.pid

      @work.relations.each do |relation|
        xml.item do
          xml.title relation.related_work.title
          xml.description "#{relation.relation_type.inverse_title} #{@work.pid} via #{relation.source.title}"
          xml.pubDate relation.related_work.published_on.to_time.utc.to_s(:rfc822)
          xml.link relation.related_work.pid
          xml.guid relation.related_work.pid
        end
      end
    end
  end
end
