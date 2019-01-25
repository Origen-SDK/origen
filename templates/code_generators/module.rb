module <%= @namespaces.map { |n| camelcase(n[1]) }.join('::') %>::<%= camelcase(@name) %>
  # def my_method
  # end
end
