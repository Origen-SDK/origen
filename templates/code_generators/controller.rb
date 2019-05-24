# If this class gets too big you may want to split it up into modules, run the following
# command to add a module to it:
#
<% if @block -%>
#   origen new module <%= Pathname.new(resource_path_to_blocks_dir(@resource_path)).relative_path_from(Origen.root) %>/controller.rb my_module_name
<% else -%>
#   origen new module <%= Pathname.new(resource_path_to_lib_file(@resource_path)).relative_path_from(Origen.root) %> my_module_name
<% end -%>
#
class <%= @namespaces.map { |n| camelcase(n[1]) }.join('::') %>::<%= camelcase(@name) %>Controller<%= @parent_class ? " < #{@parent_class}Controller" : '' %>
<% if @root_class -%>
  include Origen::Controller

<% end -%>

  # If implemented, this method will be called automatically at the start of every pattern.
<% if @top_level -%>
  # Since this is the top-level/DUT controller, it will be called first and it is normally used
  # to define a mode entry sequence.
<% else-%>
  # Since this is a sub-block controller, it will be called after the top-level/DUT controller's
  # startup method, though the calling order with relation to other sub-blocks is undefined.
<% end -%>
  # Any option arguments passed into Pattern.create will be passed into here.
  # def startup(options = {})
  #   tester.set_timeset('func', 100)
  # end
<% if @top_level -%>

  # If implemented, this method will be called automatically at the start of every simulation.
  # If the simulation run contains multiple patterns run back to back, then this method will
  # be called only once at the very start, and then the startup method will be called multiple
  # as it is invoked before each individual pattern.
  # def simulation_startup(options = {})
  #   tester.set_timeset('func', 100)
  # end

  # If implemented, this method will be called automatically at the start of every interactive
  # console session (origen i). It is commonly used to startup the simulator if the tester is
  # an OrigenSim driver as shown in the example below.
  # def interactive_startup(options = {})
  #   tester.start if tester.sim?
  # end
<% end -%>

  # All requests to read a register will be passed in here, this is where you define
  # how registers should be read (e.g. via JTAG) for this particular DUT
  def read_register(reg, options = {})
<% if @root_class -%>
<% if @top_level -%>
    Origen.log.error "A request was made to read register #{reg.name}, but the controller method has not been implemented yet!"
<% else-%>
    # Pass this to the DUT by default, if you need a special implementation or if you wish
    # to pass some meta-data to the DUT about how to handle registers from this sub-block
    # then you can do so here
    dut.read_register(reg, options)
<% end -%>
<% else-%>
    # super means that the read register request will get passed onto the parent class's
    # read_register method - i.e. the one defined in <%= @parent_class %>Controller.
    # If you want to override that and add a specific implementation for this DUT type,
    # then simply delete the super below and add the code you wish to handle the request.
    super
<% end -%>
  end

  # All requests to write a register will be passed in here, this is where you define
  # how registers should be written (e.g. via JTAG) for this particular DUT
  def write_register(reg, options = {})
<% if @root_class -%>
<% if @top_level -%>
    Origen.log.error "A request was made to write register #{reg.name}, but the controller method has not been implemented yet!"
<% else -%>
    # Pass this to the DUT by default, if you need a special implementation or if you wish
    # to pass some meta-data to the DUT about how to handle registers from this sub-block
    # then you can do so here
    dut.write_register(reg, options)
<% end -%>
<% else-%>
    # super means that the write register request will get passed onto the parent class's
    # write_register method - i.e. the one defined in <%= @parent_class %>Controller.
    # If you want to override that and add a specific implementation for this DUT type,
    # then simply delete the super below and add the code you wish to handle the request.
    super
<% end -%>
  end
end
