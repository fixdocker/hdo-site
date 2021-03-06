# -*- coding: utf-8 -*-

class Party < ActiveRecord::Base
  mount_uploader :logo, PartyUploader

  extend FriendlyId

  include Hdo::Search::Index
  add_index_callbacks

  settings(SearchSettings.default) {
    mappings {
      indexes :name, type: :string, boost: 20
      indexes :slug, type: :string, boost: 20
    }
  }

  has_many :party_memberships,  dependent: :destroy
  has_many :representatives,    through:   :party_memberships
  has_many :promises,           as:        :promisor

  has_and_belongs_to_many :governments

  has_many :proposition_endorsements, as: :proposer
  has_many :propositions, through: :proposition_endorsements

  validates :name,        presence: true, uniqueness: true
  validates :external_id, presence: true, uniqueness: true

  friendly_id :external_id, use: :slugged

  attr_accessible :name

  def self.in_government
    gov = Government.current.first
    gov ? gov.parties : []
  end

  def in_government?(date = Date.today)
    gov = Government.for_date(date).first
    gov && gov.parties.include?(self)
  end

  def current_representatives
    representatives_at(Date.today).select(&:attending?)
  end

  def representatives_at(date)
    party_memberships.includes(:representative).for_date(date).map(&:representative).sort_by(&:last_name)
  end

  def short_name
    case external_id
    when 'A'
      'Ap'
    when 'V', 'H'
      name
    else
      external_id
    end
  end

  # TODO: move to DB

  TWITTER_IDS = {
    'a'    => 'Arbeiderpartiet',
    'frp'  => 'frp_no',
    'h'    => 'Hoyre',
    'krf'  => 'KrFNorge',
    'mdg'  => 'Partiet',
    'sp'   => 'Senterpartiet',
    'sv'   => 'SVParti',
    'v'    => 'Venstre',
    'r'    => 'raudt',
    'uav'  => nil
  }

  def twitter_id
    TWITTER_IDS.fetch slug
  end

  def image
    logger.warn "Party#image is deprecated, use Party#logo (from #{caller(0).to_s})"
    logo
  end
end
