require "spec_helper"

describe "Origen commands" do

  specify "-v works" do
    output = `origen -v`
    output.should include "Application: #{Origen.app.version}"
    output.should include "Origen: #{Origen.version}"

    if Origen.os.windows?
      output = `cd / && origen -v`
    else	
      output = `cd ~/ && origen -v`
    end
    output.should_not include "Application: #{Origen.app.version}"
    output.should include "Origen: #{Origen.version}"
  end

  specify "target works" do
    begin
      output = `origen t production`
      output = `origen t`
      output.should_not include "No target has been specified"
      output.should include "$nvm"
    ensure
      Origen.target.default = "debug"
    end
  end

end

