class AddAggregationsTable < ActiveRecord::Migration
  def up
    remove_foreign_key "months", "relations"
    remove_foreign_key "months", "relation_types"

    create_table "aggregations", force: :cascade do |t|
      t.integer  "work_id",      limit: 4,                                        null: false
      t.integer  "source_id",    limit: 4,                                        null: false
      t.integer  "total",        limit: 4,        default: 0,                     null: false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    add_index "aggregations", ["source_id", "total"], name: "index_on_source_id_total"
    add_index "aggregations", ["work_id", "source_id", "total"], name: "index_on_work_id_source_id_total"

    add_column :relations, :month_id, :integer, limit: 4
    add_column :months, :aggregation_id, :integer, limit: 4
    remove_column :months, :relation_id
    remove_column :months, :relation_type_id

    add_index "relations", ["month_id"], name: "relations_month_id_fk"

    add_foreign_key "aggregations", "sources", name: "aggregations_source_id_fk", on_delete: :cascade
    add_foreign_key "aggregations", "works", name: "aggregations_work_id_fk", on_delete: :cascade
    add_foreign_key "months", "aggregations", name: "months_aggregations_id_fk", on_delete: :cascade
    add_foreign_key "relations", "months", name: "relations_months_id_fk", on_delete: :cascade
  end

  def down
    remove_foreign_key "aggregations", "sources"
    remove_foreign_key "aggregations", "works"
    remove_foreign_key "months", "aggregations"
    remove_foreign_key "relations", "months"

    remove_column :relations, :month_id
    remove_column :months, :aggregation_id
    add_column :months, :relation_id, :integer, limit: 4
    add_column :months, :relation_type_id, :integer, limit: 4

    drop_table :aggregations

    add_foreign_key "months", "relations", name: "months_relations_id_fk", on_delete: :cascade
    add_foreign_key "months", "relation_types", name: "months_relation_types_id_fk", on_delete: :cascade
  end
end
