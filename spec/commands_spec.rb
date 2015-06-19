require "spec_helper"

describe "RGen commands" do

  specify "-v works" do
    output = `rgen -v`
    output.should include "Application: #{RGen.app.version}"
    output.should include "RGen: #{RGen.version}"

    if RUBY_PLATFORM == "i386-mingw32" then
      output = `cd / && rgen -v`
    else	
      output = `cd ~/ && rgen -v`
      output.should_not include "Application: #{RGen.app.version}"
      output.should include "RGen: #{RGen.version}"
    end
  end

  specify "target works" do
    begin
      output = `rgen t production`
      output = `rgen t`
      output.should_not include "No target has been specified"
      output.should include "$nvm"
    ensure
      RGen.target.default = "debug"
    end
  end

end

