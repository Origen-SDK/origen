class Object
  # Tries the given methods and returns the first one to return a value,
  # ultimately returns nil if no value is found.
  def try(*methods)
    methods.each do |method|
      if self.respond_to?(method)
        val = send(method)
        return val if val
      end
    end
    nil
  end
end
