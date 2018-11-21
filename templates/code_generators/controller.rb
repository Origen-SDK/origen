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
<%= indent %>  def read_register(reg, options = {})
<% unless @root_class -%>
<%= indent %>    super
<% end -%>
<%= indent %>  end
<%= indent %>
<%= indent %>  def write_register(reg, options = {})
<% unless @root_class -%>
<%= indent %>    super
<% end -%>
<%= indent %>  end
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
