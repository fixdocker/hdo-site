class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable

  attr_accessible :email, :password, :password_confirmation, :remember_me, :name, :role, :description, :active, :board, :title

  has_many :last_updated_issues, foreign_key: 'last_updated_by_id', class_name: 'Issue'
  has_many :issues, foreign_key: 'editor_id', order: :title

  ROLES = %w[contributor admin superadmin]
  validates :role, presence: true, inclusion: { in: ROLES }

  scope :active, -> { where(active: true) }

  def admin?
    role == 'admin'
  end

  def superadmin?
    role == 'superadmin'
  end

  def contributor?
    role == 'contributor'
  end

  def first_name
    name.split(' ').first
  end

  def percentage_of_issues
    if Issue.count.zero?
      0
    else
      issues.size * 100 / Issue.count
    end
  end
end
