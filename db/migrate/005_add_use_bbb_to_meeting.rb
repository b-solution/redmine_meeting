class AddUseBbbToMeeting < ActiveRecord::Migration
  def change
    add_column :meetings, :use_bbb, :boolean, default: true
  end
end