module RGen
  class Application
    class PluginsManager
      # Returns the temporary plugin instance if set, otherwise nil
      attr_reader :temporary

      # Returns the current plugin instance, this will be the temporary plugin if set, if
      # not then the current default plugin if set, otherwise nil
      def current
        if @disabled || @set_to_nil
          nil
        else
          temporary || default
        end
      end
      alias_method :instance, :current
      alias_method :current_plugin_instance, :current

      def disable
        @disabled = true
      end

      def enable
        @disabled = false
      end

      # Returns the current plugin name, equivalent to calling current.name
      def name
        current ? current.name : nil
      end

      # Sets the given plugin as the temporary current plugin, this will last until
      # changed or the end of the current RGen thread
      def temporary=(plugin_name)
        if !plugin_name || plugin_name.to_sym == :none
          @set_to_nil = true
          @temporary = nil
        else
          @set_to_nil = false
          @temporary = find_plugin!(plugin_name)
        end
      end

      # Same as temporary= except it will be remembered in the next RGen thread.
      # Setting this will also clear any temporary assignment that is currently in
      # effect.
      def default=(plugin_name)
        self.temporary = nil
        if !plugin_name || plugin_name.to_sym == :none
          @default = nil
        else
          @default = find_plugin!(plugin_name)
          RGen.app.session.rgen_core[:default_plugin] = @default.name
          @default
        end
      end

      # Returns the current plugin instance currently set as the default plugin,
      # otherwise nil
      def default
        return @default if @default
        if name = RGen.app.session.rgen_core[:default_plugin]
          begin
            @default = find_plugin!(name)
          rescue
            # Hit here if what has been set to the default plugin has since been
            # removed from the application
            self.default = :none
            nil
          end
        end
      end

      # Checks the given plugin name with the list of installed plugins
      # and returns true if found else returns false
      def valid_plugin_name?(plugin_name)
        RGen.import_manager.names.include?(plugin_name)
      end

      # Lists all the plugins available on server
      def list
        puts 'The following plugins are available to add to your application:'
        puts ''
        RGen.client.plugins.group_by { |p| p[:category] }.sort_by { |k, _v| k }.each do |category, plugins|
          puts category.upcase
          puts '=' * category.length
          plugins.sort_by { |p| p[:name] }.each do |plugin|
            line =  "#{plugin[:rgen_name]}".ljust(25) + plugin[:name].strip.ljust(30)
            if plugin[:latest_version_prod] || plugin[:latest_version_dev]
              line += [plugin[:latest_version_prod] || plugin[:latest_version_dev]].compact.join(', ')
            end
            puts line
          end
          puts ''
        end
      end

      # Updates the plugin to the supplied version
      def update(plugin_name, version)
        if plugin_name.class != Symbol
          plugin_name = plugin_name.to_sym
        end
        if valid_plugin_name?(plugin_name)
          update_config_file!(version:     version,
                              plugin_name: plugin_name,
                              action:      :update)
        else
          puts "Plugin #{plugin_name} not found in this app!"
        end
      end

      # Adds the given plugin to the current app
      def add(plugin_name, version, options)
        if plugin_name.class != Symbol
          plugin_name = plugin_name.to_sym
        end
        if !valid_plugin_name?(plugin_name)
          plugin_data = read_plugin_info_from_server(plugin_name)
          update_config_file!(vault:       plugin_data[:vault],
                              version:     version,
                              plugin_name: plugin_name,
                              action:      :add,
                              dev_import:  options[:dev_import])

          puts 'Plugin added successfully!'
        else
          puts "Plugin #{plugin_name} is already included in this app!"
        end
      end

      def remove(plugin_name)
        if plugin_name.class != Symbol
          plugin_name = plugin_name.to_sym
        end
        if valid_plugin_name?(plugin_name)
          update_config_file!(plugin_name: plugin_name,
                              action:      :remove)
          if File.exist?("#{imports_dir}/#{plugin_name}")
            FileUtils.rm_rf("#{imports_dir}/#{plugin_name}")
            puts "Plugin '#{plugin_name}' removed successfully!"
          end
        else
          puts "Plugin #{plugin_name} not found in this app!"
        end
      end

      # Lists out the currently added plugins within the app on console
      def list_added_plugins
        puts 'The following plugins are included in this app:'
        format = "%30s\t%30s\t%30s\n"
        printf(format, 'RGen_Name', 'Name', 'Version')
        printf(format, '---------', '----', '-------')

        RGen.plugins.each do |plugin|
          printf(format, plugin.name, plugin.config.name, plugin.version)
        end
        puts ''
      end

      # Describes the plugin
      def describe(plugin_name)
        if plugin_name
          if plugin_name.class != Symbol
            plugin_name = plugin_name.to_sym
          end
          description = nil
          RGen.client.plugins.each do |plugin|
            if plugin[:rgen_name].to_sym == plugin_name
              description = <<-EOT
RGen_Name:    #{plugin[:rgen_name]}
Actual Name:  #{plugin[:name]}
Category:     #{plugin[:category]}
Description:  #{plugin[:description]}
EOT
              break
            end
          end
          if description.nil?
            puts "Plugin #{plugin_name} not found or it does not include a description"
            exit 1
          end
          description
        else
          puts 'No plugin name provided'
          exit 1
        end
      end

      private

      def find_plugin!(name)
        plugin = RGen.plugins.find { |p| p.name.to_sym == name.to_sym }
        return plugin if plugin
        puts ''
        puts "No plugin named '#{name}' is included in this application!"
        puts 'The plugins currently available are:'
        RGen.plugins.each do |plugin|
          puts "  #{plugin.name}"
        end
        puts ''
        fail 'Missing plugin error!'
      end

      def read_plugin_info_from_server(plugin_name)
        plugin_data = nil
        RGen.client.plugins.each do |plugin|
          if plugin[:rgen_name].to_sym == plugin_name
            plugin_data = plugin
            break
          end
        end

        if plugin_data.nil?
          fail "No plugin with name #{plugin_name} found!"
        end
        plugin_data
      end

      def update_config_file!(options = {})
        file = "#{RGen.root}/config/application.rb"
        lines = File.readlines(file)
        if options[:action] == :add && !valid_plugin_name?(options[:plugin_name])
          if options[:dev_import]
            unless lines.find_index { |line| line =~ /config.imports_dev/ }
              index = lines.find_index { |line| line =~ /config.vault =/ }
              lines.insert(index + 1, '  config.imports_dev = [', '', '  ]')
            end
          else
            unless lines.find_index { |line| line =~ /config.imports\s=\s/ }
              index = lines.find_index { |line| line =~ /config.vault =/ }
              lines.insert(index + 1, '  config.imports = [', '', '  ]')
            end
          end

          File.open(file, 'w') do |f|
            lines.each do |line|
              f.puts line
              if line =~ (options[:dev_import] ? (/config.imports_dev\s=\s/) : (/config.imports\s=\s/))
                f.puts '    {'
                f.puts "      :vault => \"#{options[:vault]}\","
                f.puts "      :version => \"#{options[:version]}\","
                if (options[:dev_import] ? (RGen.config.imports_dev) : (RGen.config.imports)).size == 0
                  f.puts '    }'
                else
                  f.puts '    },'
                end
              end
            end
          end
        elsif options[:action] == :remove && valid_plugin_name?(options[:plugin_name])
          lines.slice!(plugin_index_range(lines, options))
          File.open(file, 'w') { |f| lines.each { |line| f.puts line } }
        elsif options[:action] == :update && valid_plugin_name?(options[:plugin_name])
          range = plugin_index_range(lines, options)
          version_index = lines[range].find_index { |line| line =~ /:version/ }
          version_index += range.first
          lines[version_index] = "      :version => \"#{options[:version]}\","
          File.open(file, 'w') { |f| lines.each { |line| f.puts line } }
        end
        load "#{RGen.root}/config/application.rb"
        RGen.import_manager.required = false
        RGen.import_manager.require!
      end

      def plugin_index_range(file_lines, options)
        center = file_lines.find_index { |line| line =~ /:vault(.*)(#{options[:plugin_name]})/i }
        if center
          first = file_lines[0..center].length - 1 - file_lines[0..center].rindex.find_index { |line| line =~ /^(\s*)({)(\s*)$/ }
          last = file_lines[center..(file_lines.size - 1)].find_index { |line| line =~ /^\s*}(,?)\s*$/ }
          last = center + last
          first..last
        end
      end

      def imports_dir
        RGen.application.workspace_manager.imports_directory
      end
    end
  end
end
