module Origen
  # === Task: $ origen -t [target]
  # Sets or displays the default target.<br>
  # The default target is the one that will be
  # be used anytime you run an origen task without supplying a target via the -t option.
  # ==== Supplying a target name
  # The target argument can be any of the following:
  # * A path to a file in the target directory, e.g. origen -t target/p2_production.rb
  # * The name of a target, e.g. origen -t p2_production.rb
  # * A fragment of a name. If this is enough to uniquely identify a target in from the
  #   the target directory then this will be used, otherwise the list of possible matches
  #   will be displayed. e.g. origen -t p2
  # * A MOO number. The mapping of the MOO number to a target must be defined in
  #   the production_targets attribute of Project. e.g. origen -t 1m79x
  #
  Origen.load_application

  target = ARGV.shift
  if target
    Origen.app.target.default = target
    puts "Target now set to: #{Origen.app.target.file.basename}"
  else
    Origen.app.target.describe
  end

  exit 0
end
