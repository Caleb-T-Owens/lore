# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_28_120000) do
  create_table "repos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.text "embedding"
    t.datetime "last_pushed_at"
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.string "path", null: false
    t.text "tags", default: "[]", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "name"], name: "index_repos_on_owner_id_and_name", unique: true
    t.index ["owner_id"], name: "index_repos_on_owner_id"
    t.index ["path"], name: "index_repos_on_path", unique: true
  end

  create_table "stars", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "repo_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["repo_id"], name: "index_stars_on_repo_id"
    t.index ["user_id", "repo_id"], name: "index_stars_on_user_id_and_repo_id", unique: true
    t.index ["user_id"], name: "index_stars_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "pat_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "repos", "users", column: "owner_id"
  add_foreign_key "stars", "repos"
  add_foreign_key "stars", "users"
end
