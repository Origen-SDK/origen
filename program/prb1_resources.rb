# Similar to the test flows an interface instance is passed in as the first argument.
Resources.create do

  self.resources_filename = "prb1"

  # Logic here should be minimal, 
  # pass whatever options you want
  # but the recommended approach is
  # to infer the pattern name and as
  # many additional details as 
  # possible from the test name
  func :program_ckbd, :duration => :dynamic

  import "efa_resources"
  
  func :margin_read1_ckbd
  func :normal_read_ckbd
  func :margin_read0_ckbd

  func :erase_all, :duration => :dynamic

  para "charge_pump", :high_voltage => true

  test_instances.render "templates/j750/vt_instances"

  compile "templates/j750/program_sheet.txt", :passed_param => true

end
