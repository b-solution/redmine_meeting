class MeetingsController < ApplicationController
  unloadable

  before_filter :find_project_by_project_id
  before_filter :authorize
  before_filter :get_meeting, only: [:edit, :update, :destroy, :show]


  helper :custom_fields
  include CustomFieldsHelper
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :issues
  include IssuesHelper

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
      scope = @query.results_scope(:order => sort_clause)
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

    @meeting.safe_attributes= params[:meeting].permit!

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
    @meeting.safe_attributes= params[:meeting].permit!

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

  private

  def get_meeting
    @meeting = Meeting.find(params[:id])
  end
end
