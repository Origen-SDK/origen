module RGen
  class Generator
    # The stage provides a way to store objects in named banks for later retrieval.
    # This is typically used during pattern generation to generate header, body and
    # footer elements of a pattern in non-sequential order, allowing them to be
    # combined at the end into the logical order.
    class Stage
      def initialize
        @vault = {}
      end

      def reset!
        @vault = {}
      end

      # Returns vectors from the end of the bank
      def last_vector(offset = 0)
        offset = offset.abs
        i = current_bank.size - 1
        while offset >= 0
          return nil if i < 0
          unless current_bank[i].is_a?(String)
            return current_bank[i] if offset == 0
            offset -= 1
          end
          i -= 1
        end
      end

      # Same as last_vector except it returns the last objects of any
      # type, not just vectors
      def last_object(offset = 0)
        i = current_bank.size - 1 - offset
        current_bank[i]
      end

      # Store a new value in the current bank
      def store(obj)
        current_bank.push(obj)
      end

      # Insert a new object into the current bank X places from the end
      def insert_from_end(obj, x)
        # Ruby insert is a bit un-intuative in that insert(1) will insert something 1 place in from the
        # start, whereas insert(-1) will insert it at the end (0 places in from the end).
        # So the subtraction of 1 here aligns the behavior when inserting from the start or the end.
        current_bank.insert((x * -1) - 1, obj)
      end

      # Insert a new object into the current bank X places from the start
      def insert_from_start(obj, x)
        current_bank.insert(x, obj)
      end

      # Pull the last item added to the current bank
      def newest
        current_bank.pop
      end

      # Pull the oldest item added to the current bank
      def oldest
        current_bank.shift
      end

      # Set the current bank
      def bank=(name)
        @bank = name
      end

      # Returns the entire bank, an array
      def bank(name = @bank)
        @vault[name] || []
      end

      def current_bank
        return @vault[@bank] if @vault[@bank]
        @vault[@bank] = []
      end

      # Temporarily switches to the given bank
      def with_bank(bank)
        orig_bank = @bank
        @bank = bank
        yield
        @bank = orig_bank
      end
    end
  end
end
