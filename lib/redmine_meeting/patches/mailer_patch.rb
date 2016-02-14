require_dependency 'mailer'

module  RedmineMeeting
  module  Patches
    module MailerPatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)
      base.class_eval do

      end
    end

  end
  module ClassMethods

  end

  module InstanceMethods
    def send_meeting(meeting, users)
      redmine_headers 'Project' => meeting.project.identifier,
                      'Meeting-Author' => meeting.user.login


      @meeting = meeting
      @users = users
      @meeting_url = url_for(:controller => 'meeting', :action => 'show', :id => meeting.id)
      mail :to => users.map(&:mail),
           :subject => "[#{meeting.project.name} - ##{meeting.id}] (#{meeting.status}) #{meeting.subject}"
    end
  end

end
end