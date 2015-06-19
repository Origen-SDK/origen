  # begin
  if RGen.command_dispatcher.snapshots_exist?
    ix = ARGV.index('--snapshot_rev')
    if ix
      ARGV.delete_at(ix)
      version = ARGV[ix]
      ARGV.delete_at(ix)
    else
      version = :latest
    end

    RGen.command_dispatcher.create_workspace(version) do |workspace|
      workspace.execute(ARGV)
    end

  else
    fail 'Sorry no worker snapshots could be found!'
  end

# rescue
#  RGen.command_dispatcher.record_error
# end
