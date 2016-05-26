class AddIssueIdToMeeting < ActiveRecord::Migration
  def change
    add_column :meetings, :issue_id, :integer, default: nil
  end
end