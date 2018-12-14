module <%= @namespaces.map { |n| n[1].camelcase }.join('::') %>::<%= @name.camelcase %>
  # def my_method
  # end
end
