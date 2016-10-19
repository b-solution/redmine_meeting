class MeetingsController < ApplicationController
  unloadable

  before_filter :find_project_by_project_id
  before_filter :authorize
  before_filter :get_meeting, only: [:edit, :update, :destroy, :show, :start_conference, :join_conference, :delete_conference]


  helper :custom_fields
  include CustomFieldsHelper
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :issues
  include IssuesHelper


  require 'digest/sha1'


  require 'open-uri'
  require 'openssl'
  require 'base64'
  require 'rexml/document'
  require "tzinfo"
  # require 'ri_cal'

  def index
    @query = MeetingQuery.build_from_params(params, :name => '_')

    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
        when 'csv', 'pdf'
          @limit = Setting.issues_export_limit.to_i
          if params[:columns] == 'all'
            @query.column_names = @query.available_inline_columns.map(&:name)
          end
        when 'atom'
          @limit = Setting.feeds_limit.to_i
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
          @query.column_names = %w(author)
        else
          @limit = per_page_option
      end
      scope = @query.results_scope(:order => sort_clause, project_id: @project.try(:id))
      @entry_count = scope.count
      @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
      @meetings = scope.offset(@entry_pages.offset).limit(@entry_pages.per_page).all
      render :layout => !request.xhr?
    else
      respond_to do |format|
        format.html { render(:template => 'issues/index', :layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end


  def new
    @meeting = Meeting.new(project_id: @project.id, status: 'New')
  end

  def create
    @meeting = Meeting.new(project_id: @project.id,
                           status: 'New',
                           user_id: User.current.id)

    if Redmine::VERSION::MAJOR > 2
      @meeting.safe_attributes= params[:meeting].permit!
    else
      @meeting.safe_attributes= params[:meeting]
    end


    if @meeting.save
      users = User.where(id: params[:users])
      @meeting.users<< users
      # TODO Send notification for all members
      Mailer.deliver_send_meeting(@meeting, users)

      flash[:notice] = "Meeting created successfully"
      redirect_back_or_default project_meetings_path(@project)
    else
      render :new
    end

  end

  def show

  end


  def edit
  end

  def update
    if Redmine::VERSION::MAJOR > 2
      @meeting.safe_attributes= params[:meeting].permit!
    else
      @meeting.safe_attributes= params[:meeting]
    end


    if @meeting.save
      users = User.where(id: params[:users])
      @meeting.users= users
      flash[:notice] = "Meeting updated successfully"
      redirect_back_or_default project_meetings_path(@project)
    else
      render :edit
    end
  end

  def destroy
    @meeting.destroy
    redirect_back_or_default project_meetings_path(@project)
  end


  def join_conference
    back_url = Setting.plugin_redmine_meeting['bbb_url'].empty? ? request.referer.to_s : Setting.plugin_redmine_meeting['bbb_url']
    if params[:from_mail]
      back_url = url_for(:controller => 'meetings', :action => 'index', :project_id => @project)
    end
    ok_to_join = false
    #First, test if meeting room already exists
    server = Setting.plugin_redmine_meeting['bbb_ip'].empty? ? Setting.plugin_redmine_meeting['bbb_server'] : Setting.plugin_redmine_meeting['bbb_ip']
    moderatorPW=Digest::SHA1.hexdigest("root"+"#{@project.identifier}#{@meeting.try(:id)}")
    attendeePW=Digest::SHA1.hexdigest("guest"+"#{@project.identifier}#{@meeting.try(:id)}")

    data = callApi(server, "getMeetingInfo","meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}" + "&password=" + moderatorPW, true)
    redirect_to back_url if data.nil?
    doc = REXML::Document.new(data)
    if doc.root.elements['returncode'].text != "FAILED"
      moderatorPW = doc.root.elements['moderatorPW'].text
      server = Setting.plugin_redmine_meeting['bbb_server']
      url = callApi(server, "join", "meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}" + "&password="+ (User.current.allowed_to?(:conference_moderator, @project) ? moderatorPW : attendeePW) + "&fullName=" + CGI.escape(User.current.name) + "&userID=" + User.current.id.to_s, false)
      redirect_to url
    else
      #Meeting room doesn't exist
      start_conference
      #redirect_to back_url
    end
  end

  def start_conference
    back_url = Setting.plugin_redmine_meeting['bbb_url'].empty? ? request.referer.to_s : Setting.plugin_redmine_meeting['bbb_url']
    if params[:from_mail]
      back_url = url_for(:controller => 'meetings', :action => 'index', :project_id => @project)
    end
    ok_to_join = false
    #First, test if meeting room already exists
    server = Setting.plugin_redmine_meeting['bbb_ip'].empty? ? Setting.plugin_redmine_meeting['bbb_server'] : Setting.plugin_redmine_meeting['bbb_ip']
    moderatorPW=Digest::SHA1.hexdigest("root"+"#{@project.identifier}#{@meeting.try(:id)}")
    attendeePW=Digest::SHA1.hexdigest("guest"+"#{@project.identifier}#{@meeting.try(:id)}")

    data = callApi(server, "getMeetingInfo","meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}" + "&password=" + moderatorPW, true)
    redirect_to back_url if data.nil?
    doc = REXML::Document.new(data)
    if doc.root.elements['returncode'].text == "FAILED"
      #If not, we created it...
      if User.current.allowed_to?(:start_conference, @project)
        bridge = "77777" + @project.id.to_s + @meeting.id.to_s
        bridge = bridge[-5,5]
        s = Setting.plugin_redmine_meeting['bbb_initpres']
        loadPres = ""
        if !s.nil? && !s.empty?
          loadPres = "<?xml version='1.0' encoding='UTF-8'?><modules><module name='presentation'><document url='#{s}'/></module></modules>"
        end
        record = "false"
        if params[:record]
          record = "true"
        end
        data = callApi(server, "create","name=" + CGI.escape("#{@project.name} # #{@meeting.try(:subject)}") + "&meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}" + "&attendeePW=" + attendeePW + "&moderatorPW=" + moderatorPW + "&logoutURL=" + back_url + "&voiceBridge=" + bridge + "&record=" + record, true, loadPres)
        ok_to_join = true
      end
    else
      ok_to_join = true if User.current.allowed_to?(:join_conference, @project)
    end
    #Now, join meeting...
    if ok_to_join
      join_conference
    else
      redirect_to back_url
    end
  end

  def delete_conference
    server = Setting.plugin_redmine_meeting['bbb_ip'].empty? ? Setting.plugin_redmine_meeting['bbb_server'] : Setting.plugin_redmine_meeting['bbb_ip']
    if params[:record_id]
      data = callApi(server, "getRecordings","meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}", true)
      if !data.nil?
        docRecord = REXML::Document.new(data)
        docRecord.root.elements['recordings'].each do |recording|
          if recording.elements['recordID'].text == params[:record_id]
            data = callApi(server, "deleteRecordings","recordID=" + params[:record_id], true)
            break
          end
        end
      end
    end
    redirect_to :action => 'index', :project_id => @project
  end


  private


  def get_meeting
    @meeting = Meeting.find(params[:id])
  end
  def callApi (server, api, param, getcontent, data="")
    salt = Setting.plugin_redmine_meeting['bbb_salt']
    tmp = api + param + salt
    checksum = Digest::SHA1.hexdigest(tmp)
    url = server + "/bigbluebutton/api/" + api + "?" + param + "&checksum=" + checksum

    if getcontent
      begin
        Timeout::timeout(Setting.plugin_redmine_meeting['bbb_timeout'].to_i) do
          if data.empty?
            connection = open(url)
            connection.read
          else
            uri = URI.parse(url)
            res = Net::HTTP.start(uri.host, uri.port) {|http|
              response, body = http.post(uri.path+"?" + uri.query, data, {'Content-type'=>'text/xml; charset=utf-8'})
              body
            }
          end
        end
      rescue Timeout::Error
        return nil
      end
    else
      url
    end
  end
end
