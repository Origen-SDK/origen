require 'pathname'

def rgen_top
  # This is set in bin/rgen
  $rgen_launch_root
end

def ruby_acceptable_to_run?
  if RUBY_PLATFORM == 'i386-mingw32'
    RUBY_VERSION >= '1.9.3'
  else
    ruby_latest?
  end
end

def ruby_latest?
  # For now assume windows is always a valid installation
  if RUBY_PLATFORM == 'i386-mingw32'
    true
  else
    RUBY_VERSION == '2.1.5' && RUBY_PATCHLEVEL && RUBY_PATCHLEVEL == 273
    # RUBY_VERSION == '1.9.3' && RUBY_PATCHLEVEL && RUBY_PATCHLEVEL == 327
  end
end

def puts_latest_policy_files
  puts <<-END
  Please contact your system administrator to have the latest versions of the following packages
  installed (when they are available you can import them by running the commands above):

  END
  File.readlines("#{rgen_top}/config/rgen.policy").each do |line|
    if line !~ /^#/
      puts "      #{line}"
    end
  end
  puts ''
end

def puts_require_latest_ruby
  puts <<-END
  It's possible that your Ruby version may be stale or out of date, please run the following commands:

  cd #{rgen_top}
  source source_setup update
  cd #{FileUtils.pwd}

  If you see this message again after performing the above steps then it may be that your site
  does not have the most recent version of the Ruby package installed.
  Please contact your system administrator to have the latest version of this package
  installed (when it is available you can re-run the commands above):

  END
  File.readlines("#{rgen_top}/config/rgen.policy").each do |line|
    if line !~ /^#/ && line =~ /ruby/
      puts "      #{line}"
    end
  end
  puts ''
end

def _running_from_tr?
  if RUBY_PLATFORM != 'i386-mingw32'
    !!(`echo $PATH` =~ /fs-rgen-/)
  end
end

unless ruby_latest?
  if ruby_acceptable_to_run?
    puts <<-END

  RGen has upgraded to a new toolset but you are currently running with the old tools.

  Your site may already have access to the new tools and you can test this by running the
  following commands which may be sufficient to remove this message:

    cd #{rgen_top}
    source source_setup update
    cd #{FileUtils.pwd}

  If that doesn't work then the most likely problem is that your site does not have the required
  packages installed and you should get some feedback to this effect when running source_setup.

  END
    puts_latest_policy_files

  else

    if _running_from_tr?
      puts <<-END
  I can see that you have added the RGen bin directory to your path, however the required Ruby
  executable is being overridden by another version that has higher precedence in your path.

  To fix this you should move the RGen bin directory higher up your path, e.g. add this at the very
  end of your setup file to place it at the head of your path:

    setenv PATH ./lbin:/run/pkg/fs-rgen-/latest/bin:$PATH

  For now you can resolve the problem in this shell by running:

    source /run/pkg/fs-rgen-/latest/rgen_setup

      END
      exit 1
    else

      puts <<-END

  Sorry but your Ruby installation is too old to guarantee that RGen will run properly.

  It's possible that you haven't installed RGen correctly, please ensure that you have followed
  the instructions here:

      http://freeshare.freescale.net:2222/public/rgen-cmty-svc/Lists/Posts/Post.aspx?ID=8

  If that doesn't help then perhaps your local copy of the tool collection is stale and
  running the following commands may help:

      cd #{rgen_top}
      source source_setup update
      cd #{FileUtils.pwd}

  If that doesn't work then the most likely problem is that your site does not have the required
  packages installed and you should get some feedback to this effect when running source_setup.

  END
      puts_latest_policy_files
      exit 1
    end
  end
end
