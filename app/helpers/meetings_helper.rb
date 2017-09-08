module MeetingsHelper

  def render_sidebar_conference
    output = "".html_safe
    begin
      if !Setting.plugin_redmine_meeting['bbb_server'].empty? && (User.current.allowed_to?(:join_conference, @project) || User.current.allowed_to?(:start_conference, @project))
        url = Setting.plugin_redmine_meeting['bbb_help'].html_safe
        link = url.empty? ? "".html_safe : "&nbsp;&nbsp;<a href='".html_safe + url + "' target='_blank' class='icon icon-help'>&nbsp;</a>".html_safe

        output << "<br/><br/><h3>#{l(:label_conference)}#{link}</h3>".html_safe

        server = Setting.plugin_redmine_meeting['bbb_ip'].empty? ? Setting.plugin_redmine_meeting['bbb_server'] : Setting.plugin_redmine_meeting['bbb_ip']
        meeting_started=false
        #First, test if meeting room already exists
        moderatorPW=Digest::SHA1.hexdigest("root"+ "#{@project.identifier}#{@meeting.try(:id)}")
        data = callApi(server, "getMeetingInfo","meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}" + "&password=" + moderatorPW, true)
        return "" if data.nil?
        doc = REXML::Document.new(data)
        if doc.root.elements['returncode'].text == "FAILED" || doc.root.elements['attendees'].nil? || doc.root.elements['attendees'].size == 0
          output << "#{l(:label_conference_status)}: <b>#{l(:label_conference_status_closed)}</b><br><br>".html_safe
        else
          meeting_started = true
          recording_status = ""
          if !doc.root.elements['recording'].nil? && doc.root.elements['recording'].text.downcase == "true"
            recording_status = image_tag("recorder.png", :plugin => "redmine_meetings", :alt => l(:label_recording_meeting), :title => l(:label_recording_meeting))
          end
          if Setting.plugin_redmine_meeting['bbb_popup'] != '1'
            output << link_to(l(:label_join_conference), join_conference_project_meeting_path(@project, @meeting) )
          else
            output << ("<a href='' onclick='return start_meeting(\"" + join_conference_project_meeting_url(@project, @meeting) + "\");'>#{l(:label_join_conference)}</a>").html_safe
          end
          output << "<br><br>".html_safe
          output << "#{l(:label_conference_status)}: <b>#{l(:label_conference_status_running)}</b>#{recording_status}".html_safe
          output << "<br><i>#{l(:label_conference_people)}:</i><br>".html_safe

          doc.root.elements['attendees'].each do |attendee|
            user_id = attendee.elements['userID'].text.to_i
            user = user_id == 0 ? nil : User.find(user_id)
            name = user.nil? ? "&nbsp;&nbsp;- " + attendee.elements['fullName'].text : link_to("- "+ attendee.elements['fullName'].text, :controller => 'users', :action => 'show', :id => user.id)
            output << "#{name}<br>".html_safe
          end
        end

        if !meeting_started
          if User.current.allowed_to?(:start_conference, @project)
            if Setting.plugin_redmine_meeting['bbb_popup'] != '1'
              output << link_to(l(:label_conference_start), start_conference_project_meeting_path(@project, @meeting))
              if Setting.plugin_redmine_meeting['bbb_recording'] == '1'
                output << "<br><br>".html_safe
                output << link_to(l(:label_conference_start_with_record), start_conference_project_meeting_path(@project, @meeting, :record => true))
              end
            else
              output << ("<a href='' onclick='return start_meeting(\"" + start_conference_project_meeting_url(@project, @meeting) + "\");'>#{l(:label_conference_start)}</a>").html_safe
              if Setting.plugin_redmine_meeting['bbb_recording'] == '1'
                output << "<br><br>".html_safe
                output << ("<a href='' onclick='return start_meeting(\"" + start_conference_project_meeting_url(@project, @meeting, :record => true) + "\");'>#{l(:label_conference_start_with_record)}</a>").html_safe
              end
            end
            output << "<br><br>".html_safe
          end
        end

        #Records
        if Setting.plugin_redmine_meeting['bbb_recording'] == '1' && User.current.allowed_to?(:view_recorded_conference, @project)
          output << "<br/><br/><h3>#{l(:label_conference_records)}</h3>".html_safe
          dataRecord = callApi(server, "getRecordings","meetingID=" + "#{@project.identifier}#{@meeting.try(:id)}", true)
          return "" if dataRecord.nil?
          docRecord = REXML::Document.new(dataRecord)
          if docRecord.root.elements['returncode'].text == "FAILED" || docRecord.root.elements['recordings'].nil? || docRecord.root.elements['recordings'].size == 0
            output << "<b>#{l(:label_conference_no_records)}</b><br><br>".html_safe
          else
            meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meeting['meeting_timezone']]
            docRecord.root.elements['recordings'].each do |recording|
              next if recording.is_a? REXML::Text
              dateRecord = Time.at(recording.elements['startTime'].text.to_i / 1000)
              dataFormated = meeting_tz.local_to_utc(dateRecord).strftime("%F %R")
              #dataFormated = Time.at(recording.elements['startTime'].text.to_i).strftime("%F %R")
              playback_url = recording.elements['playback'].elements['format'].elements['url'].text
              if !playback_url.start_with?("/")
                playback_url = "/" + playback_url
              end
              if !Setting.plugin_redmine_meeting['bbb_ip'].empty?
             
                playback_url = Setting.plugin_redmine_meeting['bbb_server'] + playback_url[(Setting.plugin_redmine_meeting['bbb_ip'].length+1)..-1]

              end
              output << ("&nbsp;&nbsp;- <a href='#{playback_url}' target='" + (Setting.plugin_redmine_meeting['bbb_popup'] != '1' ? '_self' : '_blank') + "'>"+ format_time(dataFormated) + "</a>").html_safe
              if User.current.allowed_to?(:start_conference, @project)
                output << "&nbsp;&nbsp;".html_safe
                output << link_to(image_tag("delete.png"), delete_conference_project_meeting_path(@project, @meeting, :record_id => recording.elements['recordID'].text, :only_path => true), :data => { :confirm => l(:text_are_you_sure)}, :title => l(:label_delete_record))
              end
              output << ("<br>").html_safe
            end
          end
        end

      end
    rescue => exc
      output = exc
    end
    return output
  end
  
  def link_to_meeting(meeting, options={})
    subject = truncate(meeting.subject, :length => 60)
    if options[:truncate]
      subject = truncate(meeting.subject, :length => options[:truncate])
    end
    o = link_to "##{meeting.id}: ", {:controller => "meetings", :action => "show_meeting", :id => meeting},
                :class => meeting.css_classe

    if !options[:no_subject]
      o << h(subject)
    end
    o
  end

  
  def meeting_style_time (meeting, day, min, max, ind)
    meeting_tz = User.current.time_zone ? User.current.time_zone : ActiveSupport::TimeZone[Setting.plugin_redmine_meeting['meeting_timezone']]
    start_date = meeting_tz.utc_to_local(meeting.start_date.to_time)
    end_date = meeting_tz.utc_to_local(meeting.end_date.to_time)
    if start_date.day < day.day
      top = 0
    else
      h = start_date.hour
      if h < min
        top = (h * 100 / min).to_i
      elsif h > max
        top = ((h - max) * 100 / (24 - max)).to_i
      else
        t = 100
        h = h - min
        t = t + (h * 30) + (start_date.min / 2)
        top = t.to_i
      end
    end

    if end_date.day > day.day
      height = ((max - min) * 30) + 195
    else
      h = end_date.hour
      if h < min
        height = (h * 100 / min).to_i
      elsif h > max
        height = ((h - max) * 100 / (24 - max)).to_i
      else
        t = 100
        h = h - min
        t = t + (h * 30) + (end_date.min / 2)
        height = t.to_i
      end
    end
    height = height - top

    "top: #{top}px; height: #{height}px; z-order: #{top}; position: absolute; left: #{ind * 10}px;"
  end

  private

  def each_xml_element(node, name)
    if node && node[name]
      if node[name].is_a?(Hash)
        yield node[name]
      else
        node[name].each do |element|
          yield element
        end
      end
    end
  end

  def callApi (server, api, param, getcontent)
    salt = Setting.plugin_redmine_meeting['bbb_salt']
    tmp = api + param + salt
    checksum = Digest::SHA1.hexdigest(tmp)
    url = server + "/bigbluebutton/api/" + api + "?" + param + "&checksum=" + checksum

    if getcontent
      begin
        Timeout::timeout(Setting.plugin_redmine_meeting['bbb_timeout'].to_i) do
          connection = open(url)
          connection.read
        end
      rescue Timeout::Error
        return nil
      end
    else
      url
    end

  end
end
