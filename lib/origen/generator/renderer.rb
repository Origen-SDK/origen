module Origen
  class Generator
    # Handles the recursive rendering and importing of sub templates
    # and source files
    module Renderer
      def render(file, options = {}, &block)
        fail 'File argument is nil' unless file

        file = Origen.file_handler.clean_path_to_sub_template(file)
        current_pipeline << { file: file, options: options,
                              placeholder: placeholder, block: block,
                              indent: options[:indent] || 0
                            }
        if block_given?
          self.current_buffer += current_pipeline.last[:placeholder] + "\n"
        end
        current_pipeline.last[:placeholder]
      end
      alias_method :import, :render

      def placeholder
        @ix ||= 0
        @ix += 1
        "_origen_render_placeholder_#{@ix}"
      end

      def options
        @current_options ||= {}
      end

      def pipeline
        @pipeline ||= []
        @pipeline << [] if @pipeline.empty?
        @pipeline
      end

      def current_pipeline
        pipeline.last
      end

      # Insert rendered content into any placeholders
      def insert(content)
        while current_pipeline.size > 0
          current = current_pipeline.pop
          pipeline << []
          @current_options = current[:options]
          self.current_buffer = ''
          output = compile(current[:file],
                           sub_template: true,
                           block: current[:block],
                           scope: @scope
                          )
          if current[:indent] && current[:indent] > 0
            indent = ' ' * current[:indent]
            output = output.split("\n").map { |l| indent + l }.join("\n")
          end
          @current_options = nil
          content = insert_content(content, current[:placeholder], output)
        end
        pipeline.pop
        # Always give back a string, this is what existing callers expect
        #
        # Possible this could in future run into problems if the whole file cannot be read
        # into memory, but we can cross that path when we come to it
        if content.is_a?(Pathname)
          c = content.read
          content.delete
          c
        else
          content
        end
      end

      def insert_content(current, placeholder, content)
        # Start using the disk for storing the output rather than memory
        # once it starts to exceed this length
        max_length = 1_000_000
        if current.is_a?(Pathname) || content.is_a?(Pathname) ||
           ((current.length + content.length) > max_length)
          unless current.is_a?(Pathname)
            t = temporary_file
            t.open('w') { |f| f.puts current }
            current = t
          end
          new = temporary_file
          new.open('w') do |new_f|
            current.each_line do |line|
              if line.strip == placeholder
                if content.is_a?(Pathname)
                  content.each_line do |line|
                    new_f.puts line
                  end
                  content.delete
                else
                  new_f.puts content.chomp
                end
              else
                new_f.puts line
              end
            end
          end
          current.delete
          new
        else
          current.sub(/ *#{placeholder}/, content)
        end
      end

      # Returns a Pathname to a uniquely named temporary file
      def temporary_file
        # Ensure this is unique so that is doesn't clash with parallel compile processes
        Pathname.new "#{Origen.root}/tmp/compiler_#{Process.pid}_#{Time.now.to_f}"
      end
    end
  end
end
