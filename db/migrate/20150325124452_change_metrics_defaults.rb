class ChangeMetricsDefaults < ActiveRecord::Migration
  def up
    change_column :retrieval_statuses, :pdf, :integer, default: 0, null: false
    change_column :retrieval_statuses, :html, :integer, default: 0, null: false
    change_column :retrieval_statuses, :readers, :integer, default: 0, null: false
    change_column :retrieval_statuses, :comments, :integer, default: 0, null: false
    change_column :retrieval_statuses, :likes, :integer, default: 0, null: false
    change_column :retrieval_statuses, :total, :integer, null: false

    change_column :months, :pdf, :integer, default: 0, null: false
    change_column :months, :html, :integer, default: 0, null: false
    change_column :months, :readers, :integer, default: 0, null: false
    change_column :months, :comments, :integer, default: 0, null: false
    change_column :months, :likes, :integer, default: 0, null: false

    change_column :days, :pdf, :integer, default: 0, null: false
    change_column :days, :html, :integer, default: 0, null: false
    change_column :days, :readers, :integer, default: 0, null: false
    change_column :days, :comments, :integer, default: 0, null: false
    change_column :days, :likes, :integer, default: 0, null: false

    change_column :api_responses, :pdf, :integer, default: 0, null: false
    change_column :api_responses, :html, :integer, default: 0, null: false
    change_column :api_responses, :total, :integer, default: 0, null: false

    RetrievalStatus.update_all(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0, extra: nil) if !!RetrievalStatus rescue false
    Month.update_all(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0) if !!Month rescue false
    Day.update_all(pdf: 0, html: 0, readers: 0, comments: 0, likes: 0) if !!Day rescue false
    Change.update_all(pdf: 0, html: 0, total: 0) if !!Change rescue false
  end

  def down
    change_column :retrieval_statuses, :pdf, :integer, default: nil, null: true
    change_column :retrieval_statuses, :html, :integer, default: nil, null: true
    change_column :retrieval_statuses, :readers, :integer, default: nil, null: true
    change_column :retrieval_statuses, :comments, :integer, default: nil, null: true
    change_column :retrieval_statuses, :likes, :integer, default: nil, null: true
    change_column :retrieval_statuses, :total, :integer, null: true

    change_column :months, :pdf, :integer, default: nil, null: true
    change_column :months, :html, :integer, default: nil, null: true
    change_column :months, :readers, :integer, default: nil, null: true
    change_column :months, :comments, :integer, default: nil, null: true
    change_column :months, :likes, :integer, default: nil, null: true

    change_column :days, :pdf, :integer, default: nil, null: true
    change_column :days, :html, :integer, default: nil, null: true
    change_column :days, :readers, :integer, default: nil, null: true
    change_column :days, :comments, :integer, default: nil, null: true
    change_column :days, :likes, :integer, default: nil, null: true

    change_column :api_responses, :pdf, :integer, default: nil, null: true
    change_column :api_responses, :html, :integer, default: nil, null: true
    change_column :api_responses, :total, :integer, default: 0, null: true
  end
end
