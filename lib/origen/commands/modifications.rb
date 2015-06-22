module Origen
  Origen.load_application
  if Origen.app.cm.modified_objects_in_workspace?
    puts 'Your workspace has the following modifications:'
    Origen.app.cm.modified_objects_in_workspace_list.each do |file|
      puts '  ' + Origen.app.cm.diff_cmd + ' ' + file
    end
  else
    puts 'Your workspace is clean!'
  end
  exit 0
end
