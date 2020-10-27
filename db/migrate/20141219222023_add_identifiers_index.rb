class AddIdentifiersIndex < ActiveRecord::Migration
  def up
    remove_column :users, :username, limit: 191
    change_column :users, :email, :string, limit: 191, null: true

    add_index "works", ["pmid", "published_on", "id"], name: "index_works_on_pmid_published_on_id"
    add_index "works", ["pmid"], name: "index_works_on_pmid", unique: true
    add_index "works", ["pmcid", "published_on", "id"], name: "index_works_on_pmcid_published_on_id"
    add_index "works", ["pmcid"], name: "index_works_on_pmcid", unique: true
    add_index "works", ["canonical_url", "published_on", "id"], name: "index_works_on_url_published_on_id", length: { "canonical_url" => 100 }
    add_index "works", ["canonical_url"], name: "index_works_on_url", length: 100
  end

  def down
    add_column :users, :username, :string
    change_column :users, :email, :string, null: false

    remove_index "works", name: "index_works_on_pmid_published_on_id"
    remove_index "works", name: "index_works_on_pmid"
    remove_index "works", name: "index_works_on_pmcid_published_on_id"
    remove_index "works", name: "index_works_on_pmcid"
    remove_index "works", name: "index_works_on_url_published_on_id"
    remove_index "works", name: "index_works_on_url"
  end
end
