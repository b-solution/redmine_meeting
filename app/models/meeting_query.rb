class MeetingQuery < Query

  self.queried_class = Meeting

  self.available_columns = [
      QueryColumn.new(:subject, :sortable => "#{Meeting.table_name}.subject",:groupable => true),
      QueryColumn.new(:location, :sortable => "#{Meeting.table_name}.location",:groupable => true),
      QueryColumn.new(:date, :sortable => "#{Meeting.table_name}.date",:groupable => true),
      QueryColumn.new(:time, :sortable => "#{Meeting.table_name}.time",:groupable => true),
      QueryColumn.new(:status, :sortable => "#{Meeting.table_name}.status",:groupable => true),
  ]

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= {}
    add_filter('subject', '*') unless filters.present?
  end

  def initialize_available_filters
    add_available_filter "subject", :type => :string, :order => 0
    add_available_filter "date", :type => :string, :order => 1
    add_available_filter "time", :type => :string, :order => 2
    add_available_filter "location", :type => :string, :order => 3
    add_available_filter "status", :type => :string, :order => 4

    # add_custom_fields_filters(MeetingCustomField.where(:is_filter => true))
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    # @available_columns += CustomField.where(:type => 'MeetingCustomField').all.map {|cf| QueryCustomFieldColumn.new(cf) }
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= [:subject, :date, :time, :location, :status]
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    Meeting.visible.
        where(statement).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(',')))
  end

  def meetings

  end
end
