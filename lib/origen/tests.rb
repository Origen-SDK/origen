require_relative './tests/test'
module Origen
  module Tests
    def tests(expr = nil)
      if expr.nil?
        if @_tests.nil?
          @_tests = {}
        elsif @_tests.is_a? Hash
          if @_tests.empty?
            @_tests
          else
            @_tests.ids
          end
        else
          @_tests = {}
        end
      else
        @_tests.recursive_find_by_key(expr)
      end
    end

    def add_test(id, options = {}, &block)
      @_tests ||= {}
      if @_tests.include?(id)
        Origen.log.error("PPEKit: Cannot create test '#{id}', it already exists!")
        fail
      end
      @_tests[id] = Test.new(id, options, &block)
    end
  end
end
