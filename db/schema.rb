# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20160601190132) do

  create_table "answers", :force => true do |t|
    t.text     "body",                                     :null => false
    t.integer  "question_id"
    t.integer  "representative_id"
    t.string   "status",            :default => "pending", :null => false
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
  end

  create_table "categories", :force => true do |t|
    t.string   "external_id"
    t.integer  "parent_id"
    t.string   "name"
    t.boolean  "main"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "slug"
  end

  add_index "categories", ["slug"], :name => "index_categories_on_slug", :unique => true

  create_table "categories_issues", :id => false, :force => true do |t|
    t.integer "category_id"
    t.integer "issue_id"
  end

  add_index "categories_issues", ["category_id", "issue_id"], :name => "index_categories_issues_on_category_id_and_issue_id"

  create_table "categories_parliament_issues", :id => false, :force => true do |t|
    t.integer "parliament_issue_id"
    t.integer "category_id"
  end

  add_index "categories_parliament_issues", ["parliament_issue_id", "category_id"], :name => "index_cat_par_issue_on_par_issue_id_cat_id"

  create_table "categories_promises", :id => false, :force => true do |t|
    t.integer "promise_id"
    t.integer "category_id"
  end

  add_index "categories_promises", ["promise_id", "category_id"], :name => "index_categories_promises_on_promise_id_and_category_id"

  create_table "committee_memberships", :force => true do |t|
    t.integer  "representative_id", :null => false
    t.integer  "committee_id",      :null => false
    t.date     "start_date",        :null => false
    t.date     "end_date"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "committee_memberships", ["representative_id", "committee_id", "start_date", "end_date"], :name => "index_committee_memberships_on_all"

  create_table "committees", :force => true do |t|
    t.string   "external_id"
    t.string   "name"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "slug"
  end

  add_index "committees", ["slug"], :name => "index_committees_on_slug", :unique => true

  create_table "districts", :force => true do |t|
    t.string   "external_id"
    t.string   "name"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "slug"
  end

  add_index "districts", ["slug"], :name => "index_districts_on_slug", :unique => true

  create_table "email_events", :force => true do |t|
    t.string   "email_address",        :null => false
    t.string   "email_type",           :null => false
    t.integer  "email_eventable_id"
    t.string   "email_eventable_type"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
  end

  add_index "email_events", ["id", "email_eventable_type", "email_eventable_id"], :name => "email_event_index", :unique => true

  create_table "governments", :force => true do |t|
    t.string   "name"
    t.date     "start_date"
    t.date     "end_date"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "governments_parties", :id => false, :force => true do |t|
    t.integer "party_id"
    t.integer "government_id"
  end

  add_index "governments_parties", ["party_id", "government_id"], :name => "index_governments_parties_on_party_id_and_government_id"

  create_table "issues", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.datetime "created_at",                                    :null => false
    t.datetime "updated_at",                                    :null => false
    t.string   "slug"
    t.integer  "last_updated_by_id"
    t.string   "status",             :default => "in_progress"
    t.integer  "lock_version",       :default => 0,             :null => false
    t.integer  "editor_id"
    t.datetime "published_at"
    t.boolean  "frontpage",          :default => false
  end

  add_index "issues", ["slug"], :name => "index_issues_on_slug", :unique => true

  create_table "issues_questions", :id => false, :force => true do |t|
    t.integer "question_id"
    t.integer "issue_id"
  end

  add_index "issues_questions", ["question_id", "issue_id"], :name => "index_issues_questions_on_question_id_and_issue_id"

  create_table "links", :force => true do |t|
    t.string "external_id"
    t.text   "title"
    t.text   "href"
    t.string "link_type"
    t.string "link_sub_type"
  end

  create_table "links_parliament_issues", :id => false, :force => true do |t|
    t.integer "link_id"
    t.integer "parliament_issue_id"
  end

  add_index "links_parliament_issues", ["link_id", "parliament_issue_id"], :name => "index_links_par_issues"

  create_table "parliament_issues", :force => true do |t|
    t.string   "external_id"
    t.text     "summary"
    t.text     "description"
    t.string   "issue_type"
    t.string   "status"
    t.datetime "last_update"
    t.string   "document_group"
    t.string   "reference"
    t.integer  "committee_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.string   "slug"
  end

  add_index "parliament_issues", ["committee_id"], :name => "index_parliament_issues_on_committee_id"
  add_index "parliament_issues", ["slug"], :name => "index_parliament_issues_on_slug", :unique => true

  create_table "parliament_issues_votes", :id => false, :force => true do |t|
    t.integer "parliament_issue_id"
    t.integer "vote_id"
  end

  add_index "parliament_issues_votes", ["vote_id", "parliament_issue_id"], :name => "index_par_issues_votes_on_vote_id_and_par_issue_id", :unique => true

  create_table "parliament_periods", :force => true do |t|
    t.string   "external_id"
    t.date     "start_date",  :null => false
    t.date     "end_date",    :null => false
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "parliament_periods", ["external_id"], :name => "index_parliament_periods_on_external_id", :unique => true

  create_table "parliament_sessions", :force => true do |t|
    t.string   "external_id"
    t.date     "start_date",  :null => false
    t.date     "end_date",    :null => false
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "parliament_sessions", ["external_id"], :name => "index_parliament_sessions_on_external_id", :unique => true

  create_table "parties", :force => true do |t|
    t.string   "external_id"
    t.string   "name"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.string   "slug"
    t.string   "logo"
  end

  add_index "parties", ["name"], :name => "index_parties_on_name"
  add_index "parties", ["slug"], :name => "index_parties_on_slug", :unique => true

  create_table "parties_positions", :id => false, :force => true do |t|
    t.integer "position_id"
    t.integer "party_id"
  end

  add_index "parties_positions", ["party_id", "position_id"], :name => "index_parties_positions_on_party_id_and_position_id"

  create_table "party_comments", :force => true do |t|
    t.text     "body"
    t.integer  "party_id"
    t.integer  "issue_id"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.integer  "parliament_period_id"
  end

  add_index "party_comments", ["issue_id"], :name => "index_party_comments_on_issue_id"
  add_index "party_comments", ["party_id"], :name => "index_party_comments_on_party_id"

  create_table "party_memberships", :force => true do |t|
    t.integer  "representative_id", :null => false
    t.integer  "party_id",          :null => false
    t.date     "start_date",        :null => false
    t.date     "end_date"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "party_memberships", ["representative_id", "party_id", "start_date", "end_date"], :name => "index_party_memberships_on_all"

  create_table "positions", :force => true do |t|
    t.text     "description"
    t.integer  "issue_id"
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
    t.string   "title"
    t.integer  "priority",             :default => 0
    t.integer  "parliament_period_id"
  end

  create_table "promise_connections", :force => true do |t|
    t.string   "status"
    t.integer  "promise_id"
    t.integer  "issue_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "promise_connections", ["promise_id", "issue_id"], :name => "index_promise_connections_on_promise_id_and_issue_id"

  create_table "promises", :force => true do |t|
    t.text     "body"
    t.boolean  "general"
    t.string   "source"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.string   "external_id"
    t.integer  "page"
    t.integer  "parliament_period_id"
    t.integer  "promisor_id"
    t.string   "promisor_type"
  end

  add_index "promises", ["promisor_id", "promisor_type"], :name => "index_promises_on_promisor_id_and_promisor_type"

  create_table "proposition_connections", :force => true do |t|
    t.integer  "vote_id"
    t.integer  "issue_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.text     "comment"
    t.text     "title"
    t.integer  "proposition_id"
  end

  add_index "proposition_connections", ["proposition_id"], :name => "index_proposition_connections_on_proposition_id"
  add_index "proposition_connections", ["vote_id", "issue_id"], :name => "index_proposition_connections_on_vote_id_and_issue_id"

  create_table "proposition_endorsements", :force => true do |t|
    t.integer "proposition_id"
    t.integer "proposer_id"
    t.string  "proposer_type"
    t.boolean "inferred",       :default => false
  end

  create_table "propositions", :force => true do |t|
    t.string   "external_id"
    t.string   "description"
    t.text     "body"
    t.string   "on_behalf_of"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.string   "simple_description"
    t.text     "simple_body"
    t.boolean  "interesting",        :default => true
    t.boolean  "starred",            :default => false
  end

  create_table "propositions_votes", :id => false, :force => true do |t|
    t.integer "proposition_id"
    t.integer "vote_id"
  end

  add_index "propositions_votes", ["proposition_id", "vote_id"], :name => "index_propositions_votes_on_proposition_id_and_vote_id"

  create_table "questions", :force => true do |t|
    t.text     "body",                                     :null => false
    t.string   "status",            :default => "pending", :null => false
    t.string   "from_name"
    t.string   "from_email"
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
    t.integer  "representative_id"
    t.boolean  "show_sender",       :default => true
    t.string   "internal_comment"
    t.text     "rejection_reason"
    t.datetime "approved_at"
  end

  create_table "representatives", :force => true do |t|
    t.string   "external_id"
    t.string   "first_name"
    t.string   "last_name"
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.integer  "district_id"
    t.datetime "date_of_birth"
    t.datetime "date_of_death"
    t.string   "slug"
    t.string   "twitter_id"
    t.string   "email"
    t.string   "image"
    t.string   "encrypted_password",     :default => "",    :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.boolean  "attending",              :default => false
    t.boolean  "opted_out"
    t.boolean  "substitute",             :default => false
    t.string   "wikidata_id"
  end

  add_index "representatives", ["attending"], :name => "index_representatives_on_attending"
  add_index "representatives", ["confirmation_token"], :name => "index_representatives_on_confirmation_token", :unique => true
  add_index "representatives", ["district_id"], :name => "index_representatives_on_district_id"
  add_index "representatives", ["email"], :name => "index_representatives_on_email", :unique => true
  add_index "representatives", ["last_name"], :name => "index_representatives_on_last_name"
  add_index "representatives", ["reset_password_token"], :name => "index_representatives_on_reset_password_token", :unique => true
  add_index "representatives", ["slug"], :name => "index_representatives_on_slug", :unique => true

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "context",       :limit => 128
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type", "context"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_context"

  create_table "tags", :force => true do |t|
    t.string "name"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "",      :null => false
    t.string   "encrypted_password",     :default => "",      :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.string   "name"
    t.string   "role",                   :default => "admin", :null => false
    t.text     "description"
    t.boolean  "active"
    t.boolean  "board"
    t.string   "title",                  :default => ""
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

  create_table "vote_results", :force => true do |t|
    t.integer  "representative_id"
    t.integer  "vote_id"
    t.integer  "result"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "vote_results", ["representative_id", "vote_id"], :name => "index_vote_results_on_representative_id_and_vote_id"

  create_table "votes", :force => true do |t|
    t.string   "external_id"
    t.integer  "for_count"
    t.integer  "against_count"
    t.integer  "absent_count"
    t.boolean  "enacted"
    t.text     "subject"
    t.datetime "time"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
    t.string   "slug"
    t.boolean  "personal",      :default => true
    t.string   "comment"
  end

  add_index "votes", ["slug"], :name => "index_votes_on_slug", :unique => true

end
