# An example of creating an entire test program from
# a single source file
Flow.create do

  self.resources_filename = "prb2"

  func :erase_all, :duration => :dynamic

  func :margin_read1_all1

  func :erase_all, :duration => :dynamic
  func :margin_read1_all1

  import "components/prb2_main"

  func :erase_all, :duration => :dynamic
  func :margin_read1_all1, id: "erased_successfully"

  skip if_all_passed: "erased_successfully" do
    import "components/prb2_main"
  end

  if_enable "extra_tests" do
    import "components/prb2_main"
  end

  func :margin_read1_all1

end
