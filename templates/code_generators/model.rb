<% indent = '' -%>
<% @namespaces.each_with_index do |namespace, i| -%>
<%= indent %>module <%= namespace.camelcase %>
<% indent += '  ' -%>
<% end -%>
<%= indent %>class <%= @name.camelcase %>
<% if @top_level -%>
<%= indent %>  include Origen::TopLevel
<% else -%>
<%= indent %>  include Origen::Model
<% end -%>
<%= indent %>
<%= indent %>  def initialize(options = {})
<%= indent %>    define_registers(options)
<%= indent %>    define_sub_blocks(options)
<%= indent %>  end
<%= indent %>
<%= indent %>  # Define this model's registers within this method
<%= indent %>  def define_registers(options = {})
<%= indent %>  end
<%= indent %>
<%= indent %>  # Define this model's sub_blocks within this method
<%= indent %>  def define_sub_blocks(options = {})
<%= indent %>  end
<%= indent %>end
<% @namespaces.each_with_index do |namespace, i| -%>
<% indent = indent.slice(0..-3) -%>
<%= indent %>end
<% end -%>
