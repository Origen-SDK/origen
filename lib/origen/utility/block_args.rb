module Origen
  module Utility
    # BlockArgs provides a neat way to pass multiple block arguments to a method
    # that the method can then used in various ways.
    #
    # (blocks in Ruby are merely nameless methods you can pass to methods as an argument. Used to pass ruby code to a method basically.)
    #
    # A single BlockArgs object is an array of these blocks that can be added or
    # deleted.
    #
    #   def handle_some_blocks(options={})
    #
    #     blockA = Origen::Utility::BlockArgs.new
    #     blockB = Origen::Utility::BlockArgs.new
    #
    #     yield blockA, blockB
    #
    #     puts "Handling blocks!"
    #
    #     if options[:block_to_run] == :blockA
    #       blockA.each do |block|
    #         block.call
    #       end
    #     else
    #       blockB.each do |block|
    #         block.call
    #       end
    #     end
    #
    #     puts "Done handling blocks!"
    #
    #   end
    #
    # To then use the above method:
    #
    #   handle_some_blocks(options) do |blockA, blockB|
    #     blockA.add do
    #       puts "do task 1"
    #     end
    #     blockA.add do
    #       puts "do task 2"
    #     end
    #     blockB.add do
    #       puts "do task 3"
    #     end
    #   end
    #
    # Many blocks can be added in this case to either the blockA or blockB BlockArg objects.
    # The only reason 2 BlockArg objects are used above is that handle_some_blocks wants to use
    # different blocks depending on an option argument.
    #
    # This is a very powerful way to put code specific to one application in a different method in
    # different class (e.g. handle_some_blocks) where the code calling it doesn't need to know
    # exact implementation details.
    #
    class BlockArgs
      # any Enumerable methods also can be used
      # e.g. each_with_index
      include Enumerable

      # Creates a new BlockArgs object
      def initialize
        @block_args = []
      end

      # Adds a block to the BlockArgs object
      def add(&block)
        @block_args << block
      end

      # Deletes a block to the BlockArgs object
      def delete(&block)
        @block_args.delete(block)
      end

      # required to enumerate objects for Enumerable
      # iterator returns each block at a time
      def each
        @block_args.each do |arg|
          yield arg
        end
      end

      # same as each but returns index of each block
      # instead of block itself.
      def each_index
        @block_args.each_index do |i|
          yield i
        end
      end
    end
  end
end
