module RGen
  RGen.load_application
  if RGen.app.cm.modified_objects_in_workspace?
    puts 'Your workspace has the following modifications:'
    RGen.app.cm.modified_objects_in_workspace_list.each do |file|
      puts '  ' + RGen.app.cm.diff_cmd + ' ' + file
    end
  else
    puts 'Your workspace is clean!'
  end
  exit 0
end
