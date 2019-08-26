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
  
  # Indicates whether the object is or can be used as an Origen subblock, where
  # being an Origen subblock is defined as inheriting from either {Origen::Model} or
  # {Origen::Controller}.
  # @return [True/False]
  # @example Subblock NVM (from the Origen guides)
  #   dut.nvm.origen_subblock? #=> true
  # @example Non-subblocks
  #   'hi'.origen_subblock? #=> false
  # @see https://origen-sdk.org/origen/guides/models/defining/#Adding_Sub_Blocks
  def origen_subblock?
    self.class.ancestors.include?(Origen::Model) || self.class.ancestors.include?(Origen::Controller)
  end
  alias_method :origen_sub_block?, :origen_subblock?
  
end
