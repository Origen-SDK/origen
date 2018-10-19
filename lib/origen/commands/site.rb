require 'optparse'
require 'pathname'
require 'origen/commands/helpers'

module Origen
   options = {}
   
  # App options are options that the application can supply to extend this command
  app_options = @application_options || []
  opt_parser = OptionParser.new do |opts|
    opts.banner = <<-END
  env [filters...] Shows the current site environment configuration. Analogous to 'env' for shell environment.
                  In other words, lists all the site config variables and their values.
                  Aliased to 'environment'.

  configs         Shows the current config files used and their indexes.

  inspect_config [config_indexes...] Inspects the configuration(s) at each index given.
                                     Indexes can be found from 'origen site configs'
                                     If no indexes are given, all configs are printed.

  inspect_variable [variable_names...] Inspects and traces the variable(s) through the various sites configs.

  refresh         Forces a refresh of the centralized site config. This will reset the timer for the next automatc refresh.
    END

    # Apply any application option extensions to the OptionParser
    Origen::CommandHelpers.extend_options(opts, app_options, options)
    opts.separator ''
    opts.on('-h', '--help', 'Show this message') { puts opts; exit }
  end
  opt_parser.parse! ARGV

  if ARGV[0]
    case ARGV.shift
    when 'env', 'environment'
      Origen.site_config.pretty_print_env(*ARGV)
    when 'configs'
      Origen.site_config.pretty_print_configs
    when 'inspect_config', 'inspect_configs'
      Origen.site_config.inspect_config(*ARGV)
    when 'inspect_variable', 'inspect_variables'
      Origen.site_config.inspect_variable(*ARGV)
    when 'refresh'
      Origen.site_config.refresh
    else
      puts "Unknown command, see 'origen site -h' for a list of commands"
    end
  else
    puts "You must supply a command, see 'origen site -h' for a list of commands"
  end
end

