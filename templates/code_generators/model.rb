# If this class gets too big you may want to split it up into modules, run the following
# command to add a module to it:
#
<% if @block -%>
#   origen new module <%= Pathname.new(resource_path_to_blocks_dir(@resource_path)).relative_path_from(Origen.root) %>/model.rb my_module_name
<% else -%>
#   origen new module <%= Pathname.new(resource_path_to_lib_file(@resource_path)).relative_path_from(Origen.root) %> my_module_name
<% end -%>
#
class <%= @namespaces.map { |n| camelcase(n[1]) }.join('::') %>::<%= camelcase(@name) %><%= @parent_class ? " < #{@parent_class}" : '' %>
<% if @root_class -%>
<% if @top_level -%>
  include Origen::TopLevel
<% else -%>
  include Origen::Model
<% end -%>

  def initialize(options = {})
  end
<% else -%>
# super means that the initialize request will get passed onto the parent class's initialize method. 
# i.e. the one defined in <%= @parent_class %>
  def initialize(options = {})
    super
  end
<% end -%>
end
