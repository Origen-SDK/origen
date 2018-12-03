# If this class gets too big you may want to split it up into modules, run the following
# command to add a module to it:
#
<% if @part -%>
#   origen new module my_module_name <%= Pathname.new(resource_path_to_part_dir(@resource_path)).relative_path_from(Origen.root) %>/controller.rb
<% else -%>
#   origen new module my_module_name <%= Pathname.new(resource_path_to_lib_file(@resource_path)).relative_path_from(Origen.root) %>
<% end -%>
#
<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %><%= namespace[0] %> <%= namespace[1].camelcase %>
<% indent += '  ' -%>
<% end -%>
<%= indent %>class <%= @name.camelcase %>Controller<%= @parent_class ? " < #{@parent_class}Controller" : '' %>
<% if @root_class -%>
<%= indent %>  include Origen::Controller
<%= indent %>
<% end -%>
<%= indent %>
<%= indent %>  # If implemented, this method will be called automatically at the start of every pattern.
<% if @top_level -%>
<%= indent %>  # Since this is the top-level/DUT controller, it will be called first and it is normally used
<%= indent %>  # to define a mode entry sequence.
<% else-%>
<%= indent %>  # Since this is a sub-block controller, it will be called after the top-level/DUT controller's
<%= indent %>  # startup method, though the calling order with relation to other sub-blocks is undefined.
<% end -%>
<%= indent %>  # Any option arguments passed into Pattern.create will be passed into here.
<%= indent %>  # def startup(options = {})
<%= indent %>  #   tester.set_timeset('func', 100)
<%= indent %>  # end
<% if @top_level -%>
<%= indent %>
<%= indent %>  # If implemented, this method will be called automatically at the start of every simulation.
<%= indent %>  # If the simulation run contains multiple patterns run back to back, then this method will
<%= indent %>  # be called only once at the very start, and then the startup method will be called multiple
<%= indent %>  # as it is invoked before each individual pattern.
<%= indent %>  # def simulation_startup(options = {})
<%= indent %>  #   tester.set_timeset('func', 100)
<%= indent %>  # end
<%= indent %>
<%= indent %>  # If implemented, this method will be called automatically at the start of every interactive
<%= indent %>  # console session (origen i). It is commonly used to startup the simulator if the tester is
<%= indent %>  # an OrigenSim driver as shown in the example below.
<%= indent %>  # def interactive_startup(options = {})
<%= indent %>  #   tester.start if tester.sim?
<%= indent %>  # end
<% end -%>
<%= indent %>
<%= indent %>  # All requests to read a register will be passed in here, this is where you define
<%= indent %>  # how registers should be read (e.g. via JTAG) for this particular DUT
<%= indent %>  def read_register(reg, options = {})
<% if @root_class -%>
<% if @top_level -%>
<%= indent %>    Origen.log.error "A request was made to read register #{reg.name}, but the controller method has not been implemented yet!"
<% else-%>
<%= indent %>    # Pass this to the DUT by default, if you need a special implementation or if you wish
<%= indent %>    # to pass some meta-data to the DUT about how to handle registers from this sub-block
<%= indent %>    # then you can do so here
<%= indent %>    dut.read_register(reg, options)
<% end -%>
<% else-%>
<%= indent %>    # super means that the read register request will get passed onto the parent class's
<%= indent %>    # read_register method - i.e. the one defined in <%= @parent_class %>Controller.
<%= indent %>    # If you want to override that and add a specific implementation for this DUT type,
<%= indent %>    # then simply delete the super below and add the code you wish to handle the request.
<%= indent %>    super
<% end -%>
<%= indent %>  end
<%= indent %>
<%= indent %>  # All requests to write a register will be passed in here, this is where you define
<%= indent %>  # how registers should be written (e.g. via JTAG) for this particular DUT
<%= indent %>  def write_register(reg, options = {})
<% if @root_class -%>
<% if @top_level -%>
<%= indent %>    Origen.log.error "A request was made to write register #{reg.name}, but the controller method has not been implemented yet!"
<% else -%>
<%= indent %>    # Pass this to the DUT by default, if you need a special implementation or if you wish
<%= indent %>    # to pass some meta-data to the DUT about how to handle registers from this sub-block
<%= indent %>    # then you can do so here
<%= indent %>    dut.write_register(reg, options)
<% end -%>
<% else-%>
<%= indent %>    # super means that the write register request will get passed onto the parent class's
<%= indent %>    # write_register method - i.e. the one defined in <%= @parent_class %>Controller.
<%= indent %>    # If you want to override that and add a specific implementation for this DUT type,
<%= indent %>    # then simply delete the super below and add the code you wish to handle the request.
<%= indent %>    super
<% end -%>
<%= indent %>  end
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
