class Source < ActiveRecord::Base
  # include methods for calculating metrics
  include Measurable

  # include date methods concern
  include Dateable

  # include summary counts
  include Countable

  # include hash helper
  include Hashie::Extensions::DeepFetch

  has_many :relations, :dependent => :destroy
  has_many :results, :dependent => :destroy
  has_many :months
  has_many :notifications
  has_many :works, :through => :results
  belongs_to :group

  serialize :config, OpenStruct

  validates :name, :presence => true, :uniqueness => true
  validates :title, :presence => true

  scope :order_by_name, -> { order("group_id, sources.title") }
  scope :active, -> { where(active: true).order_by_name }
  scope :for_results, -> { active.joins(:group).where("groups.name = ?", "results") }
  scope :for_relations, -> { active.joins(:group).where("groups.name = ?", "relations") }
  scope :for_results_and_relations, -> { active.joins(:group).where("groups.name IN (?)", ["results", "relations"]) }
  scope :for_contributions, -> { active.joins(:group).where("groups.name = ?", "contributions") }
  scope :for_publishers, -> { active.joins(:group).where("groups.name = ?", "publishers") }

  # some sources cannot be redistributed
  scope :public_sources, -> { where(private: false) }
  scope :private_sources, -> { where(private: true) }
  scope :accessible, ->(role) { where("private <= ?", role) }

  def to_param  # overridden, use name instead of id
    name
  end

  def display_name
    title
  end

  def human_state_name
    (active ? "active" : "inactive")
  end

  def get_results_by_month(results, options={})
    results = results.reject { |relation| relation["occurred_at"].nil? }

    options[:metrics] ||= :total
    results.group_by { |relation| relation["occurred_at"][0..6] }.sort.map do |k, v|
      { year: k[0..3].to_i,
        month: k[5..6].to_i,
        options[:metrics] => v.length,
        total: v.length }
    end
  end

  # Format results for all works as csv
  # Show historical data if options[:format] is used
  # options[:format] can be "html", "pdf" or "combined"
  # options[:month] and options[:year] are the starting month and year, default to last month
  def to_csv(options = {})
    if ["html", "pdf", "xml", "combined"].include? options[:format]
      view = "#{options[:name]}_#{options[:format]}_views"
    else
      view = options[:name]
    end

    # service_url = "#{ENV['COUCHDB_URL']}/_design/reports/_view/#{view}"

    result = get_result(service_url, options.merge(timeout: 1800))
    if result.blank? || result["rows"].blank?
      message = "CouchDB report for #{options[:name]} could not be retrieved."
      Notification.where(message: message).where(unresolved: true).first_or_create(
        exception: "",
        class_name: "Faraday::ResourceNotFound",
        source_id: id,
        status: 404,
        level: Notification::FATAL)
      return ""
    end

    if view == options[:name]
      CSV.generate do |csv|
        csv << ["pid_type", "pid", "html", "pdf", "total"]
        result["rows"].each { |row| csv << ["doi", row["key"], row["value"]["html"], row["value"]["pdf"], row["value"]["total"]] }
      end
    else
      dates = date_range(options).map { |date| "#{date[:year]}-#{date[:month]}" }

      CSV.generate do |csv|
        csv << ["pid_type", "pid"] + dates
        result["rows"].each { |row| csv << ["doi", row["key"]] + dates.map { |date| row["value"][date] || 0 } }
      end
    end
  end

  def timestamp
    cached_at.utc.iso8601
  end

  def cache_key
    "source/#{name}-#{timestamp}"
  end

  def update_cache
    CacheJob.perform_later(self)
  end

  def write_cache
    # update cache_key as last step so that we have the old version until we are done
    now = Time.zone.now

    # loop through cached attributes we want to update
    [:result_count,
     :work_count,
     :relation_count,
     :with_results_by_day_count,
     :without_results_by_day_count,
     :not_updated_by_day_count,
     :with_results_by_month_count,
     :without_results_by_month_count,
     :not_updated_by_month_count].each { |cached_attr| send("#{cached_attr}=", now.utc.iso8601) }

    update_column(:cached_at, now)
  end
end
