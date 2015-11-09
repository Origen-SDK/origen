module Origen
  class UndefinedClass
    include Singleton

    def inspect
      'undefined'
    end

    def undefined?
      true
    end
  end
end
