require '<%= @namespaces.join('/') %>/<%= @name %>_controller'
<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %>module <%= namespace.camelcase %>
<% indent += '  ' -%>
<% end -%>
<%= indent %>class <%= @name.camelcase %>
<%= indent %>  include Origen::TopLevel
<%= indent %>
<%= indent %>  def initialize(options = {})
<%= indent %>
<%= indent %>  end
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
