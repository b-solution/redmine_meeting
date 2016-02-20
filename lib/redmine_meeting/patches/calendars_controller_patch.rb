require_dependency 'calendars_controller'

module  RedmineMeeting
  module  Patches
    module CalendarsControllerPatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :show, :meetings
        end
      end

    end
    module ClassMethods

    end

    module InstanceMethods
      def show_with_meetings
        if params[:year] and params[:year].to_i > 1900
          @year = params[:year].to_i
          if params[:month] and params[:month].to_i > 0 and params[:month].to_i < 13
            @month = params[:month].to_i
          end
        end
        @year ||= Date.today.year
        @month ||= Date.today.month

        @calendar = Redmine::Helpers::Calendar.new(Date.civil(@year, @month, 1), current_language, :month)
        retrieve_query
        @query.group_by = nil
        if @query.valid?
          events = []
          events += @query.issues(:include => [:tracker, :assigned_to, :priority],
                                  :conditions => ["((start_date BETWEEN ? AND ?) OR (due_date BETWEEN ? AND ?))", @calendar.startdt, @calendar.enddt, @calendar.startdt, @calendar.enddt]
          )
          events += @query.versions(:conditions => ["effective_date BETWEEN ? AND ?", @calendar.startdt, @calendar.enddt])

          @q2 = MeetingQuery.build_from_params(params, :name => '_')
          events += @q2.results_scope(:conditions => ["(date BETWEEN ? AND ?)", @calendar.startdt, @calendar.enddt])

          @calendar.events = events


        end

        render :action => 'show', :layout => false if request.xhr?
      end
    end
  end
end