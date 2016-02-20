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


    def deliver_send_meeting(meeting, users)
      users.each do |user|
        Mailer.send_meeting(meeting, user).deliver
      end
    end
  end

  module InstanceMethods
    def send_meeting(meeting, user)
      redmine_headers 'Project' => meeting.project.identifier,
                      'Meeting-Author' => meeting.user.login


      @meeting = meeting
      @user = user
      @meeting_url = project_meeting_url(meeting.project, meeting)
      mail :to => user.mail,
           :subject => "[#{meeting.project.name} - ##{meeting.id}] (#{meeting.status}) #{meeting.subject}"
    end

  end

end
end