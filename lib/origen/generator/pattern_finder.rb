module Origen
  class Generator
    # The pattern finder is responsible for finding patterns in the pattern
    # directory, allowing the user to create any number of pattern files
    # in any number of sub directories without having to declare them.
    class PatternFinder
      def find(name, options)
        # If the pattern is a fully qualified path to a Ruby file, then just run that:
        if File.exist?(name) && name.strip =~ /\.rb$/
          return check(name, options)
        end

        name = File.basename(name)
        @requested_pattern = name   # Remember what was originally asked for in case
        # it needs to be output in an error message

        # Strip the prefix if exists
        if Origen.config.pattern_prefix && name =~ /^#{Origen.config.pattern_prefix}_/
          name.gsub!(/^#{Origen.config.pattern_prefix}_/, '')
        end

        # Strip the extension if present
        name.gsub!(/\.\w+$/, '')

        # Strip the postfix if exists
        if Origen.config.pattern_postfix && name =~ /_#{Origen.config.pattern_postfix}$/
          name.gsub!(/_#{Origen.config.pattern_postfix}$/, '')
        end

        # Otherwise see what can be found...
        return :skip unless proceed_with_pattern?(name) # The application has elected not to run this pattern

        pats = matching_patterns(name)
        # If the pattern is not found in current plugin and current app then look into other included plugins as well
        if pats.size == 0
          pats = all_matches(name)
        end

        if pats.size == 0
          # If a pattern can't be found see if it is because the real pattern name is actually
          # a substituted value.
          # Don't want to do this up front since it is possible that some patterns
          # will actually have an explicit value in the name.
          translation = Origen.config.pattern_name_translator(name)
          # Give the current plugin a go at translating the name if the current application
          # has not modified it
          if translation == name && Origen.app.plugins.current
            translation = Origen.app.plugins.current.config.pattern_name_translator(name)
          end
          if translation
            if translation.is_a?(Hash)
              name = translation[:source]
            else
              name = translation
              translation = nil
            end
          end
          return :skip unless proceed_with_pattern?(name) # The application has elected not to run this pattern
          pats = matching_patterns(name)
          if pats.size == 0
            pats = all_matches(name)
          end
        end

        # Last chance see if the supplied name works, this could happen if the user normally
        # substitutes the name in before_pattern but here they have a pattern that
        # actually includes the bit that is normally sub'd out
        if pats.size == 0
          pats = matching_patterns(@requested_pattern)
          if pats.size == 0
            pats = all_matches(@requested_pattern)
          end
        end

        if pats.size == 0
          fail "Can't find: #{@requested_pattern}"
        elsif pats.size > 1
          ambiguous_error(pats)
        else

          if translation
            translation.merge(pattern: check(pats.first, options))
          else
            check(pats.first, options)
          end
        end
      end

      def matching_patterns(name)
        # Remove extension in case it is something else, e.g. .atp
        name = name.gsub(/\..*$/, '')
        matches = []
        # First look into the current plugin
        if current_plugin_pattern_path
          matches = Dir.glob("#{current_plugin_pattern_path}/**/#{name}.rb").sort
          # If the current plugin does  not include the pattern then look into the current app
          if matches.size == 0
            matches = Dir.glob("#{pattern_directory}/**/#{name}.rb").sort # <= this does not include symlinks
          end
        else
          matches = Dir.glob("#{pattern_directory}/**/#{name}.rb").sort # <= this does not include symlinks
        end

        matches
      end

      def current_plugin_pattern_path
        cp = Origen.app.plugins.current
        if cp && cp.config.shared
          path = cp.config.shared[:patterns] || cp.config.shared[:pattern]
          File.join(cp.root, path) if path
        end
      end

      def all_matches(name)
        name = name.gsub(/\..*$/, '')
        matches = Dir.glob("#{pattern_directory}/**{,/*/**}/#{name}.rb").sort # Takes symlinks into consideration
        matches.flatten.uniq
      end

      def pattern_directory
        Origen.config.pattern_directory
      end

      # Check with the application that it wishes to run the given pattern
      def proceed_with_pattern?(name)
        Origen.config.proceed_with_pattern(name)
      end

      def check(path, options = {})
        file_plugin = Origen.app.plugins.plugin_name_from_path(path)
        if file_plugin
          if Origen.app.plugins.current
            if file_plugin == Origen.app.plugins.current.name
              return proceed_with_pattern?(path) ? path : :skip
            elsif !options[:current_plugin]
              Origen.app.plugins.current.temporary = file_plugin
              return proceed_with_pattern?(path) ? path : :skip
            else
              puts "The requested pattern is from plugin #{file_plugin} and current system plugin is set to plugin #{Origen.app.plugins.current.name}!"
              fail 'Incorrect plugin error!'
            end
          else
            Origen.app.plugins.current.temporary = file_plugin
            return proceed_with_pattern?(path) ? path : :skip
          end
        else
          return proceed_with_pattern?(path) ? path : :skip
        end
      end

      def ambiguous_error(pats)
        if Origen.running_locally?
          Origen.log.info 'The following patterns match:'
          Origen.log.info pats
        end
        fail "Ambiguous name: #{@requested_pattern}"
      end
    end
  end
end
