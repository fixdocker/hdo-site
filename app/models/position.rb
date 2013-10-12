class Position < ActiveRecord::Base
  has_and_belongs_to_many :parties
  belongs_to :issue
  belongs_to :parliament_period

  attr_accessible :description, :issue_id, :parties, :title, :priority, :parliament_period_id

  validates :parties, presence: true
  validates :title,   presence: true

  def downcased_title
    @downcased_title ||= (
      t = title.to_s.strip
      "#{UnicodeUtils.downcase t[0]}#{t[1..-1]}"
    )
  end
end
