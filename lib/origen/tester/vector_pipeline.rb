module Origen
  module Tester
    class VectorPipeline
      attr_reader :group_size, :pipeline

      def initialize(group_size)
        @group_size = group_size
        @pipeline = []
      end

      # Add a vector/comment to the pipeline
      def <<(vector)
        if vector.is_a?(Vector)
          consume_comments(vector)
          if vector.repeat > 1
            add_repeat_vector(vector)
          else
            pipeline << vector
          end
        else
          comments << vector
        end
      end

      # If there are complete groups sitting at the top of the pipeline
      # then this will yield them back line by line, stopping when after the last
      # complete group and leaving any remaining single vectors in the pipeline
      # If there are no complete groups present then it will just return
      def flush
        while lead_group_finalized?
          lead_group.each do |vector|
            vector.comments.each do |comment|
              yield comment
            end
            yield vector
          end
          pipeline.shift(group_size)
        end
      end

      # Call at the end to force a flush out of any remaining vectors
      def empty
        if !pipeline.empty? || !comments.empty?
          pipeline.each do |vector|
            vector.comments.each do |comment|
              yield comment
            end
            yield vector
          end
          comments.each do |comment|
            yield comment
          end
          @pipeline = []
          @comments = []
        end
      end

      private

      # Pushes a duplicate of the given vector with its repeat set to 1
      # Also clears any comments associated with the vector with the rationale that we only
      # want to see them the first time
      def push_duplicate(vector)
        v = vector.dup
        v.repeat = 1
        pipeline << v
        vector.comments = []
      end

      def add_repeat_vector(vector)
        count = vector.repeat
        # Align to the start of a new group by splitting off single vectors
        # to complete the current group
        while !aligned? && count > 0
          push_duplicate(vector)
          count -= 1
        end
        if count > group_size
          remainder = count % group_size
          # Create a group with the required repeat
          group_size.times do
            push_duplicate(vector)
          end
          pipeline.last.repeat = (count - remainder) / group_size
          # Then expand out any leftover
          remainder.times do
            push_duplicate(vector)
          end
        # For small repeats that fit within the group just expand them
        else
          while count > 0
            push_duplicate(vector)
            count -= 1
          end
        end
      end

      # Returns true of the next vector to be added to the pipeline will
      # be at the start of a new group
      def aligned?
        (pipeline.size % group_size) == 0
      end

      def consume_comments(vector)
        vector.comments = comments
        @comments = []
      end

      def comments
        @comments ||= []
      end

      # When true the lead group is complete and a further repeat of it is not possible
      # Calling this will compress the 2nd group into the 1st if possible
      def lead_group_finalized?
        if lead_group.size == group_size
          if second_group_present?
            i = -1
            if second_group.all? do |vector|
                 i += 1
                 pipeline[i] == vector
               end
              pipeline[group_size - 1].repeat += 1
              group_size.times { pipeline.delete_at(group_size) }
              false
            else
              true
            end
          else
            false
          end
        else
          false
        end
      end

      def second_group_present?
        second_group.size == group_size
      end

      def lead_group
        pipeline[0..group_size - 1]
      end

      def second_group
        pipeline[group_size..(group_size * 2) - 1]
      end
    end
  end
end
