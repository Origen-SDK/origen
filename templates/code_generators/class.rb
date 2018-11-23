<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %><%= namespace[0] %> <%= namespace[1].camelcase %>
<% indent += '  ' -%>
<% end -%>
<%= indent %>class <%= @name.camelcase %><%= @parent_class ? " < #{@parent_class}" : '' %>
<%= indent %>  def initialize(options = {})
<%= indent %>  end
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
