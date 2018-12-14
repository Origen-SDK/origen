# If this class gets too big you may want to split it up into modules, run the following
# command to add a module to it:
#
<% if @part -%>
#   origen new module my_module_name <%= Pathname.new(resource_path_to_part_dir(@resource_path)).relative_path_from(Origen.root) %>/model.rb
<% else -%>
#   origen new module my_module_name <%= Pathname.new(resource_path_to_lib_file(@resource_path)).relative_path_from(Origen.root) %>
<% end -%>
#
class <%= @namespaces.map { |n| n[1].camelcase }.join('::') %>::<%= @name.camelcase %><%= @parent_class ? " < #{@parent_class}" : '' %>
<% if @root_class -%>
<% if @top_level -%>
  include Origen::TopLevel
<% else -%>
  include Origen::Model
<% end -%>

<% end -%>
  def initialize(options = {})
  end
end
