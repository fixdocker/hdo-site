class Promise < ActiveRecord::Base
  attr_accessible :parties, :general, :categories, :source, :body, :page, :date

  has_and_belongs_to_many :parties, :order => :name

  has_and_belongs_to_many :categories, :order => :name
  has_and_belongs_to_many :topics, :order => :title

  validates_presence_of :source, :body
  validates_uniqueness_of :body
  validates_length_of :categories, :minimum => 1
  validates_length_of :parties, :minimum => 1

  def general_text
    I18n.t(general? ? 'app.yes' : 'app.no')
  end

  def party_names
    parties.map(&:name).to_sentence
  end
end
