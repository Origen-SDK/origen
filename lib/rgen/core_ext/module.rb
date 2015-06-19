class Module
  def alias_accessor(new, orig)
    alias_reader(new, orig)
    alias_writer(new, orig)
  end

  def alias_writer(new, orig)
    alias_method("#{new}=", "#{orig}=") if method_defined?("#{orig}=")
  end

  def alias_reader(new, orig)
    alias_method(new, orig) if method_defined?(orig)
  end
end
