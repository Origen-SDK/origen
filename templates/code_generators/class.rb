# If this class gets too big you may want to split it up into modules, run the following
# command to add a module to it:
#
#   origen new module my_module_name <%= Pathname.new(resource_path_to_lib_file(@resource_path)).relative_path_from(Origen.root) %>
#
class <%= @namespaces.map { |n| camelcase(n[1]) }.join('::') %>::<%= camelcase(@name) %><%= @parent_class ? " < #{@parent_class}" : '' %>
  def initialize(options = {})
  end
end
