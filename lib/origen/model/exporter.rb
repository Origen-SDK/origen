module Origen
  module Model
    module Exporter
      # Export the model
      #
      # Options defaults:
      #   include_pins:       true
      #   include_registers:  true
      #   include_sub_blocks: true
      #   include_timestamp:  true
      #   rm_rb_only:         nil     # delete only .rb files, default is rm -rf * Origen.root/vendor/lib/models/name
      #
      # Use the rm_rb_only option if the export dir is under revision control and the dir contains revision control metadata
      def export(name, options = {})
        options = {
          include_pins:       true,
          include_registers:  true,
          include_sub_blocks: true,
          include_timestamp:  true,
          file_path:          nil
        }.merge(options)
        # file_path is for internal use, don't pass it from the application, use the :dir option if you
        # want to change where the exported files are
        file = options[:file_path] || export_path(name, options)
        dir = options[:dir_path] || export_dir(options)
        path_to_file = Pathname.new(File.join(dir, file))
        if File.exist?(path_to_file.sub_ext('').to_s)
          if options[:rm_rb_only]
            Dir.glob(path_to_file.sub_ext('').to_s + '/**/*.rb').each { |f| FileUtils.rm_f(f) }
          else
            FileUtils.rm_rf(path_to_file.sub_ext('').to_s)
          end
        end
        FileUtils.rm_rf(path_to_file.to_s) if File.exist?(path_to_file.to_s)
        FileUtils.mkdir_p(path_to_file.dirname)
        File.open(path_to_file, 'w') do |f|
          export_wrap_with_namespaces(f, options) do |indent|
            f.puts((' ' * indent) + 'def self.extended(model)')
            indent += 2
            if top_level?
              # Write out packages if any
              unless Origen.top_level.packages.empty?
                spaces = ' ' * indent
                Origen.top_level.packages.each { |p| f.puts "#{spaces}model.add_package :#{p}\n" }
              end
            end
            if options[:include_pins]
              if top_level?
                pins.each do |id, pin|
                  f.puts export_pin(id, pin, indent: indent)
                end
                pin_groups.each do |id, pins|
                  f.puts export_pin_group(id, pins, indent: indent)
                end
                power_pins.each do |id, pin|
                  f.puts export_pin(id, pin, indent: indent, method: :add_power_pin, attributes: [:voltage, :current_limit])
                end
                power_pin_groups.each do |id, pins|
                  f.puts export_pin_group(id, pins, indent: indent, method: :add_power_pin_group)
                end
                ground_pins.each do |id, pin|
                  f.puts export_pin(id, pin, indent: indent, method: :add_ground_pin)
                end
                ground_pin_groups.each do |id, pins|
                  f.puts export_pin_group(id, pins, indent: indent, method: :add_ground_pin_group)
                end
                virtual_pins.each do |id, pin|
                  f.puts export_pin(id, pin, indent: indent, method: :add_virtual_pin)
                end
                f.puts
              end
            end
            if options[:include_sub_blocks]
              sub_blocks.each do |name, block|
                f.puts export_sub_block(name, block, options.merge(indent: indent, file_path: file, dir_path: dir))
              end
              f.puts unless sub_blocks.empty?
            end

            if options[:include_registers]
              regs.each do |name, reg|
                f.puts export_reg(name, reg, indent: indent)
              end
            end

            indent -= 2
            f.puts((' ' * indent) + 'end')
          end
        end
      end

      def import(name, options = {})
        path = File.join(export_dir(options), export_path(name, options))
        if File.exist?(path)
          require path
          if options.key?(:namespace) && !options[:namespace]
            extend name.to_s.gsub('.', '_').camelcase.constantize
          else
            if options[:namespace]
              extend "#{options[:namespace].to_s.gsub('.', '_').camelcase}::#{name.to_s.gsub('.', '_').camelcase}".constantize
            else
              extend "#{Origen.app.namespace}::#{name.to_s.gsub('.', '_').camelcase}".constantize
            end
          end
          true
        else
          if options[:allow_missing]
            false
          else
            fail "The import for #{name} could not be found at #{path}"
          end
        end
      end

      private

      def write_pin_packages(pin)
        ''.tap do |str|
          unless pin.packages.empty?
            str << 'packages: { '
            pin.packages.each do |pin_pkg, pin_pkg_meta|
              pkg_end_str = (pin_pkg == pin.packages.keys.last) ? ' }' : ', '
              if pin_pkg_meta.empty?
                str << "#{pin_pkg}: {}#{pkg_end_str}"
                next
              else
                str << "#{pin_pkg}: { "
                pin_pkg_meta.each do |attr, attr_val|
                  str << "#{attr}: "
                  attr_end_str = (attr == pin_pkg_meta.keys.last) ? ' }' : ', '
                  case attr_val
                  when String
                    str << "\"#{attr_val.gsub('"', '\"')}\"#{attr_end_str}"
                  else
                    str << "#{attr_val}#{attr_end_str}"
                  end
                end
                str << pkg_end_str
              end
            end
          end
        end
      end

      def export_wrap_with_namespaces(file, options = {})
        file.puts '# This file was generated by Origen, any hand edits will likely get overwritten'
        if options[:include_timestamp]
          file.puts "# Created at #{Time.now.strftime('%e %b %Y %H:%M%p')} by #{User.current.name}"
        end
        file.puts '# rubocop:disable all'
        indent = 0
        export_module_names_from_path(file.path, options).each do |name|
          file.puts((' ' * indent) + "module #{name}")
          indent += 2
        end
        yield indent
        export_module_names_from_path(file.path, options).each do |name|
          indent -= 2
          file.puts((' ' * indent) + 'end')
        end
        file.puts '# rubocop:enable all'
      end

      def export_module_names_from_path(name, options = {})
        name = name.sub("#{export_dir(options)}/", '').sub('.rb', '')
        name.split(/[\/\\]/).map do |n|
          if n == ''
            nil
          else
            n.to_s.gsub('.', '_').camelcase
          end
        end.compact
      end

      def export_path(name, options = {})
        if options.key?(:namespace) && !options[:namespace]
          "#{name.to_s.underscore}.rb"
        else
          File.join((options[:namespace] || Origen.app.namespace).to_s.underscore, "#{name.to_s.underscore}.rb")
        end
      end

      def export_dir(options = {})
        options[:dir] || File.join(Origen.root, 'vendor', 'lib', 'models')
      end

      def export_pin(id, pin, options = {})
        indent = ' ' * (options[:indent] || 0)
        line = indent + "model.#{options[:method] || 'add_pin'} :#{id}"
        if (r = pin.instance_variable_get('@reset')) != :dont_care
          line << ", reset: :#{r}"
        end
        if (d = pin.direction) != :io
          line << ", direction: :#{d}"
        end
        pkg_meta = write_pin_packages(pin)
        line << ", #{pkg_meta}" unless pkg_meta == ''
        Array(options[:attributes]).each do |attr|
          unless (v = pin.send(attr)).nil?
            case v
            when Numeric, Array, Hash
              line << ", #{attr}: #{v}"
            when Symbol
              line << ", #{attr}: :#{v}"
            else
              line << ", #{attr}: '#{v}'"
            end
          end
        end
        unless pin.meta.empty?
          line << ', meta: { '
          line << pin.meta.map do |k, v|
            case v
            when Numeric, Array, Hash
              "#{k}: #{v}"
            when Symbol
              "#{k}: :#{v}"
            else
              "#{k}: '#{v}'"
            end
          end.join(', ')
          line << ' }'
        end
        line
      end

      def export_pin_group(id, pins, options = {})
        indent = ' ' * (options[:indent] || 0)
        line = indent + "model.#{options[:method] || 'add_pin_group'} :#{id}, "
        if pins.endian == :little
          line << pins.reverse_each.map { |p| ":#{p.id}" }.join(', ')
          line << "\n#{indent}model.pins(:#{id}).endian = :little"
        else
          line << pins.map { |p| ":#{p.id}" }.join(', ')
        end
        line
      end

      def export_sub_block(id, block, options = {})
        indent = ' ' * (options[:indent] || 0)
        file_path = File.join(Pathname.new(options[:file_path]).sub_ext(''), "#{id}.rb")
        dir_path = options[:dir_path]
        line = indent + "model.sub_block :#{id}, file: '#{file_path}', dir: \"#{dir_path.gsub(Origen.root.to_s, '#{Origen.root!}')}\", lazy: true"
        unless block.base_address == 0
          line << ", base_address: #{block.base_address.to_hex}"
        end
        block.custom_attrs.each do |key, value|
          if value.is_a?(Symbol)
            line << ", #{key}: :#{value}"
          elsif value.is_a?(String)
            line << ", #{key}: \"#{value.gsub('"', '\"')}\""
          else
            line << ", #{key}: #{value}" unless value.nil?
          end
        end
        block.export(id, options.merge(file_path: file_path, dir_path: dir_path))
        line
      end

      def export_reg(id, reg, options = {})
        indent = ' ' * (options[:indent] || 0)
        lines = []
        unless reg.description.empty?
          reg.description.each { |l| lines << indent + "# #{l}" }
        end
        lines << indent + "model.add_reg :#{id}, #{reg.offset.to_hex}, size: #{reg.size} #{reg.bit_order == :msb0 ? ', bit_order: :msb0' : ''}#{build_reg_meta(reg)} do |reg|"
        indent = ' ' * ((options[:indent] || 0) + 2)
        reg.named_bits.each do |name, bits|
          unless bits.description.empty?
            bits.description.each { |l| lines << indent + "# #{l}" }
          end
          position = reg.bit_order == :msb0 ? (reg.size - bits.position - 1) : bits.position
          if bits.size == 1
            line = indent + "reg.bit #{position}, :#{name}"
          else
            if reg.bit_order == :msb0
              line = indent + "reg.bit #{position - bits.size + 1}..#{position}, :#{name}"
            else
              line = indent + "reg.bit #{position + bits.size - 1}..#{position}, :#{name}"
            end
          end
          unless bits.access == :rw
            line << ", access: :#{bits.access}"
          end
          if bits.reset_val.is_a?(Symbol)
            line << ", reset: :#{bits.reset_val}"
          else
            line << ", reset: #{bits.reset_val.to_hex}" unless bits.reset_val == 0
          end
          lines << line
        end
        indent = ' ' * (options[:indent] || 0)
        lines << indent + 'end'
        lines.join("\n")
      end

      def build_reg_meta(reg)
        ret_str = ''
        reg.meta.each do |key, value|
          if value.is_a?(Symbol)
            ret_str += ", #{key}: :#{value}"
          elsif value.is_a?(String)
            ret_str += ", #{key}: \"#{value.gsub('"', '\"')}\""
          else
            ret_str += ", #{key}: #{value}" unless value.nil?
          end
        end
        ret_str
      end
    end
  end
end
