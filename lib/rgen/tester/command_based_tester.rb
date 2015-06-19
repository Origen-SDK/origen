module RGen
  module Tester
    # A base class that can be used to model command-based, rather than
    # vector-based testers.
    class CommandBasedTester
      include Tester

      def initialize
        @vector_based = false
      end

      # Write a string directly to the output file without being processed
      # or modified in any way
      def direct_write(str)
        microcode str
      end
      alias_method :dw, :direct_write

      # Concept of a cycle not supported, print out an error to the output
      # file to alert the user that execution has hit code that is not
      # compatible with a command based tester.
      def cycle(*_args)
        microcode '*** Cycle called ***'
      end

      # Concept of a subroutine not supported, print out an error to the output
      # file to alert the user that execution has hit code that is not
      # compatible with a command based tester.
      def call_subroutine(sub)
        microcode "Call_subroutine called to #{sub}"
      end

      def format_vector(vec)
        vec.microcode
      end

      # Loop the content embedded in the supplied block
      def loop(_name = nil, number_of_loops)
        number_of_loops.times do
          yield
        end
      end
      alias_method :loop_vector, :loop
    end
  end
end
