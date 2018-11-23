# If this class gets too big you may want to split it up into modules, run the following
# command to add a module to it:
#
<% if @part -%>
#   origen new module my_module_name <%= Pathname.new(resource_path_to_part_dir(@resource_path)).relative_path_from(Origen.root) %>/model.rb
<% else -%>
#   origen new module my_module_name <%= Pathname.new(resource_path_to_lib_file(@resource_path)).relative_path_from(Origen.root) %>
<% end -%>
#
<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %><%= namespace[0] %> <%= namespace[1].camelcase %>
<% indent += '  ' -%>
<% end -%>
<%= indent %>class <%= @name.camelcase %><%= @parent_class ? " < #{@parent_class}" : '' %>
<% if @root_class -%>
<% if @top_level -%>
<%= indent %>  include Origen::TopLevel
<% else -%>
<%= indent %>  include Origen::Model
<% end -%>
<%= indent %>
<% end -%>
<%= indent %>  def initialize(options = {})
<%= indent %>  end
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
