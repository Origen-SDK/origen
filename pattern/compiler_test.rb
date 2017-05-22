# This is a test to make sure invoking the compiler before executing a
# pattern job does not crash, this is required by origen_sim
Origen.app.runner.launch action: :compile,
                          files: "#{Origen.root}/templates/test/inline.txt.erb",
                          output: "#{Origen.root}/tmp"

Pattern.create do

end
