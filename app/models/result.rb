class Result < ActiveRecord::Base
  # include HTTP request helpers
  include Networkable

  # include methods for calculating metrics
  include Measurable

  # include helper module for query caching
  include Cacheable

  belongs_to :work, inverse_of: :results, touch: true
  belongs_to :source
  has_many :months, dependent: :destroy, inverse_of: :result

  validates :work_id, :source_id, presence: true
  validates_associated :work, :source
  validates :work_id, uniqueness: { scope: :source_id }

  after_touch :set_total

  delegate :name, :to => :source
  delegate :title, :to => :source
  delegate :group, :to => :source

  scope :tracked, -> { joins(:work).where("works.tracked = ?", true) }

  scope :last_x_days, ->(duration) { tracked.where("results.updated_at >= ?", Time.zone.now.to_date - duration.days) }
  scope :not_updated, ->(duration) { tracked.where("results.updated_at < ?", Time.zone.now.to_date - duration.days) }

  scope :published_last_x_days, ->(duration) { joins(:work).where("works.published_on >= ?", Time.zone.now.to_date - duration.days) }
  scope :published_last_x_months, ->(duration) { joins(:work).where("works.published_on >= ?", Time.zone.now.to_date  - duration.months) }

  scope :with_results, -> { where("total > ?", 0) }
  scope :without_results, -> { where("total = ?", 0) }
  scope :most_cited, -> { with_results.order("total desc").limit(25) }
  scope :with_sources, -> { joins(:source).where("sources.active = ?", 1).order("group_id, title") }

  def to_param
    "#{source.name}:#{work.pid}"
  end

  def group_name
    @group_name ||= group.name
  end

  def title
    @title ||= source.title
  end

  def timestamp
    updated_at.utc.iso8601
  end

  alias_method :display_name, :title
  alias_method :update_date, :timestamp

  def cache_key
    "result/#{id}-#{timestamp}"
  end

  # dates via utc time are more accurate than Date.today
  def today
    Time.zone.now.to_date
  end

  def by_month
    months.map do |month|
      { month: month.month,
        year: month.year,
        total: month.total }
    end
  end

  def by_year
    return [] if by_month.blank?

    by_month.group_by { |event| event[:year] }.sort.map do |k, v|
      { year: k.to_i,
        total: v.reduce(0) { |sum, hsh| sum + hsh.fetch(:total) } }
    end
  end

  def set_total
    update_columns(total: months.sum(:total))
  end

  def metrics
    @metrics ||= { total: total }
  end
end
