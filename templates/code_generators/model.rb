<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %><%= namespace[0] %> <%= namespace[1].camelcase %>
<% indent += '  ' -%>
<% end -%>
<% if @part -%>
<%= indent %># If this class gets too big you may want to split it up into modules, run the following
<%= indent %># command to add a module to it:
<%= indent %>#
<%= indent %>#   origen new module <%= @resource_path %>/model/my_module_name
<%= indent %>#
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
