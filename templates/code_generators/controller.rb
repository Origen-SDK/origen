<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %>module <%= namespace.camelcase %>
<% indent += '  ' -%>
<% end -%>
<%= indent %>class <%= @name.camelcase %>Controller
<%= indent %>  include Origen::Controller
<%= indent %>
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
