Redmine::Plugin.register :redmine_meeting do
  name 'Redmine Meeting plugin'
  author 'Ljupco Vangelski'
  description 'This is a plugin for Redmine'
  version '0.0.1'

  project_module :redmine_meeting do
    permission :view_meetings, :meetings => :index
    permission :create_meeting, :meetings => [:new, :create]
    permission :edit_meeting, :meetings => [:edit, :update , :destroy]
  end

  menu :project_menu, :meetings,
       {:controller => 'meetings', :action => 'index'},
       :caption => :label_meeting_plural,
       :before => :activity, param: :project_id


end


Rails.application.config.to_prepare do
  Project.send(:include, RedmineMeeting::Patches::ProjectPatch)
  User.send(:include, RedmineMeeting::Patches::UserPatch)
  QueriesHelper.send(:include, RedmineMeeting::Patches::QueriesHelperPatch)
  Mailer.send(:include, RedmineMeeting::Patches::MailerPatch)
  CalendarsController.send(:include, RedmineMeeting::Patches::CalendarsControllerPatch)
end

