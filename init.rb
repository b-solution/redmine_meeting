Redmine::Plugin.register :redmine_meeting do
  name 'Redmine Meeting plugin'
  author 'Ljupco Vangelski'
  description 'This is a plugin for Redmine'
  version '0.1.1'

  project_module :redmine_meeting do
    permission :view_meetings, :meetings => [:index, :show]
    permission :create_meeting, :meetings => [:new, :create]
    permission :edit_meeting, :meetings => [:edit, :update , :destroy]

    permission :join_conference, :meetings => :join_conference
    permission :start_conference, {:meetings => [:start_conference, :delete_conference]}
    permission :conference_moderator, {}
    permission :view_recorded_conference, {}
  end

  settings :default => {'bbb_server' => '', 'bbb_salt' => '', 'bbb_timeout' => '3',
                        'meeting_timezone' => 'Paris', 'bbb_recording' => ''},
           :partial => 'meeting_settings/settings'


  menu :project_menu, :meetings,
       {:controller => 'meetings', :action => 'index'},
       :caption => :label_meeting_plural,
       :before => :activity, param: :project_id


end


Rails.application.config.to_prepare do
  class Hooks < Redmine::Hook::ViewListener
    def create_or_update_meeting(context)
      issue = context[:issue]
      params = context[:params]
      create_meeting = params[:create_meeting]
      if create_meeting
        hash = {
            subject: issue.subject,
            project_id: issue.project_id,
            issue_id: issue.id,
            status: 'New',
            user_id: issue.author.id,
            location: true,
            date: issue.start_date,
            time: '08:00',
            agenda: issue.description
        }
        meeting = Meeting.where(issue_id: issue.id).first_or_initialize
        meeting.safe_attributes =hash.stringify_keys
        if meeting.save
          users = (issue.watchers.map(&:user) + [issue.assigned_to]).flatten.uniq
          new_users = meeting.new_record? ?  users : users - meeting.users
          meeting.users= users

          # TODO Send notification for all members
          Mailer.deliver_send_meeting(meeting, new_users)
        end
      end
    end
    def controller_issues_new_after_save(context={})
     create_or_update_meeting(context)
    end
    def controller_issues_edit_after_save(context={})
      create_or_update_meeting(context)
    end
    render_on :view_issues_form_details_bottom, :partial=> 'issues/create_meeting'
  end

  Project.send(:include, RedmineMeeting::Patches::ProjectPatch)
  ProjectsHelper.send(:include, RedmineMeeting::Patches::ProjectsHelperPatch)
  User.send(:include, RedmineMeeting::Patches::UserPatch)
  QueriesHelper.send(:include, RedmineMeeting::Patches::QueriesHelperPatch)
  Mailer.send(:include, RedmineMeeting::Patches::MailerPatch)
  CalendarsController.send(:include, RedmineMeeting::Patches::CalendarsControllerPatch)
end
