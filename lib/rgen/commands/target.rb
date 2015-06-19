module RGen
  # === Task: $ rgen -t [target]
  # Sets or displays the default target.<br>
  # The default target is the one that will be
  # be used anytime you run an rgen task without supplying a target via the -t option.
  # ==== Supplying a target name
  # The target argument can be any of the following:
  # * A path to a file in the target directory, e.g. rgen -t target/p2_production.rb
  # * The name of a target, e.g. rgen -t p2_production.rb
  # * A fragment of a name. If this is enough to uniquely identify a target in from the
  #   the target directory then this will be used, otherwise the list of possible matches
  #   will be displayed. e.g. rgen -t p2
  # * A MOO number. The mapping of the MOO number to a target must be defined in
  #   the production_targets attribute of Project. e.g. rgen -t 1m79x
  #
  RGen.load_application

  target = ARGV.shift
  if target
    RGen.app.target.default = target
    puts "Target now set to: #{RGen.app.target.file.basename}"
  else
    RGen.app.target.describe
  end

  exit 0
end
