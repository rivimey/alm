class DataExport < ActiveRecord::Base
  class Error < ::StandardError ; end
  class FileNotFoundError < Error ; end
  class FilePermissionError < Error ; end

  def self.data_attribute(name, options={})
    reader_method, writer_method = name, "#{name}="
    define_method(reader_method){ data.fetch(name){ options[:default] } }
    define_method(writer_method){ |value| self.data[name] = value }
  end

  def self.find_previous_version_of(export)
    query = where("name = ? AND finished_exporting_at IS NOT NULL", export.name)
    if export.type
      query = query.where("type = ?", export.type)
    else
      query = query.where("type IS NULL")
    end
    query = query.where("id <> ?", export.id) if export.id
    query.order("created_at DESC").limit(1).first
  end

  scope :not_exported, -> { where(started_exporting_at:nil, finished_exporting_at:nil) }

  serialize :data, Hash

  validates :name, presence: true

  def export!
    raise NotImplementedError, "Must implement #export! in subclass!"
  end

  def previous_version
    @previous_version ||= self.class.find_previous_version_of(self)
  end

  def state
    if failed_at
      "failed"
    elsif finished_exporting_at
      "done"
    elsif started_exporting_at
      "processing"
    else
      "pending"
    end
  end
end
