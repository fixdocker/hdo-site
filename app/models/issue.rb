class Issue < ActiveRecord::Base
  extend FriendlyId

  include Tire::Model::Search
  extend Hdo::Search::Index

  tire.settings(TireSettings.default) {
    mapping {
      indexes :description, type: :string, analyzer: TireSettings.default_analyzer
      indexes :title,       type: :string, analyzer: TireSettings.default_analyzer, boost: 100
      indexes :status,      type: :string, index: :not_analyzed
      indexes :slug,        type: :string, index: :not_analyzed
      indexes :tag_list,    type: :string, analyzer: 'keyword'

      indexes :categories do
        indexes :name, type: :string, analyzer: TireSettings.default_analyzer
      end
    }
  }

  update_index_on_change_of :categories, if: lambda { |i| i.published? }, has_many: true

  after_save    { update_search_index }
  after_destroy { tire.update_index }

  acts_as_taggable

  attr_accessible :description, :title, :category_ids, :promise_ids, :status,
                  :lock_version, :editor_id, :tag_list, :frontpage

  validates :title, presence: true, uniqueness: true
  validate :only_published_issues_on_frontpage

  STATUSES = %w[
    published
    publishable
    in_review
    in_progress
  ].freeze
  validates_inclusion_of :status, in: STATUSES

  has_and_belongs_to_many :categories, uniq: true
  has_and_belongs_to_many :questions, uniq: true, order: "updated_at DESC"

  belongs_to :last_updated_by, foreign_key: 'last_updated_by_id', class_name: 'User'
  belongs_to :editor, class_name: 'User'

  has_many :party_comments, dependent: :destroy
  has_many :proposition_connections, dependent: :destroy
  has_many :promise_connections, dependent: :destroy
  has_many :positions, dependent: :destroy, order: :priority

  has_many :promises, through: :promise_connections
  has_many :propositions, through: :proposition_connections

  friendly_id :title, use: :slugged

  scope :published,    -> { where(status: 'published') }
  scope :latest,       ->(limit) { order(:updated_at).reverse_order.limit(limit) }
  scope :random,       -> { order("random()") }

  def self.for_frontpage(limit)
    frontpage = where(frontpage: true).random.limit(limit)
    count     = frontpage.count

    if count >= limit
      result = frontpage
    else
      result = frontpage.to_a + (published.where(frontpage: false).limit(limit - count)).random
    end

    result
  end

  def self.grouped_by_position(entity)
    all.to_a.reject { |i| i.stats.score_for(entity).nil? }.
             group_by { |i| i.stats.key_for(i.stats.score_for(entity)) }
  end

  def self.grouped_by_accountability(entity)
    all.to_a.group_by { |i| i.accountability.key_for(entity) }
  end

  def self.in_tag_groups(opts = {})
    count  = opts[:count]
    min    = opts[:minimum]
    random = opts[:random]

    groups = Hash.new { |hash, key| hash[key] = [] }

    includes(:tags).each do |issue|
      issue.tags.each { |tag| groups[tag] << issue }
    end

    if min
      groups = groups.select { |tag_name, issues| issues.size >= min }
    end

    if random
      groups = groups.to_a.shuffle
    end

    count ? groups.first(count) : groups
  end

  def to_param
    "#{id}-#{slug}".parameterize
  end

  def previous_and_next(opts = {})
    issues = self.class
    issues = opts[:policy].scope if opts[:policy]
    issues = issues.order(opts[:order] || :title)

    current_index = issues.to_a.index(self)

    prev_issue = issues[current_index - 1] if current_index > 0
    next_issue = issues[current_index + 1] if current_index < issues.size

    [prev_issue, next_issue]
  end

  def position_for(party)
    positions.joins(:parties).where('parties.id' => [party]).first
  end

  def downcased_title
    # TODO: move to decorators?
    @downcased_title ||= (
      t = title.strip
      "#{UnicodeUtils.downcase t[0]}#{t[1..-1]}"
    )
  end

  def status_text
    I18n.t("app.issues.status.#{status}")
  end

  def published_state
    published? ? 'published' : 'not-published'
  end

  def published?
    status == 'published'
  end

  def last_updated_by_name
    last_updated_by ? last_updated_by.name : I18n.t('app.nobody')
  end

  def editor_name
    editor ? editor.name : I18n.t('app.nobody')
  end

  def to_indexed_json
    as_json(include: [:categories]).merge(:tag_list => tag_list).to_json
  end

  def to_json_with_stats
    to_json methods: [:stats, :accountability]
  end

  def accountability
    Rails.cache.fetch("#{cache_key}/accountability") { Hdo::Stats::AccountabilityScorer.new(self) }
  end

  def only_published_issues_on_frontpage
    if frontpage && !published?
      errors.add(:frontpage, I18n.t('app.errors.issues.must_be_published'))
    end
  end

  private

  def update_search_index
    if published?
      tire.update_index
    else
      self.index.remove self
    end
  end
end
