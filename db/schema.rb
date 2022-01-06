# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_01_06_115658) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "instance_logs", force: :cascade do |t|
    t.bigint "project_id"
    t.string "instance_type"
    t.string "instance_name"
    t.text "instance_id"
    t.string "platform"
    t.string "region"
    t.string "compute_group"
    t.string "status"
    t.date "date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["date"], name: "index_instance_logs_on_date"
    t.index ["project_id"], name: "index_instance_logs_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "platform"
    t.string "filter_level"
    t.date "start_date"
    t.date "end_date"
    t.boolean "visualiser", default: true
    t.boolean "archived", default: false
    t.string "slack_channel"
    t.string "security_id"
    t.string "security_key"
    t.json "regions"
    t.json "resource_groups"
    t.string "project_tag"
    t.string "subscription_id"
    t.string "tenant_id"
    t.text "bearer_token"
    t.text "bearer_expiry"
    t.float "utilisation_threshold"
    t.datetime "override_monitor_until"
    t.boolean "monitor_active"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
