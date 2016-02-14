class Meeting < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  belongs_to :user
  belongs_to :project

  has_many :meeting_users
  has_many :users, through: :meeting_users


  validates_presence_of :subject, :date, :time, :status, :project_id, :user_id
  validates_presence_of :meeting_minutes, :if => :check_status

  safe_attributes 'subject', 'location', 'project_id', 'user_id',
                  'time', 'status', 'date', 'agenda', 'custom_field_values', 'meeting_minutes'

  scope :visible, lambda {|*args|
    if User.current.admin?
      includes(:project)
    else
      includes(:project).where(user_id: User.current.id)
    end
  }


  def check_status
    return false if status == 'New'
    true
  end

  def editable_by?(usr= User.current)
    usr == user && usr.allowed_to?(:edit_meeting, project)
  end

  # Returns true if the attribute is required for user
  def required_attribute?(name, user=nil)
    required_attribute_names(user).include?(name.to_s)
  end
end
