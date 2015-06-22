# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/app_tasks.rake, and they will automatically be available to Rake.

# Any task files found in lib/tasks/shared/*.rake will be available to other apps that
# include this app as a plugin

require "bundler/setup"
require "origen"

Origen.app.load_tasks
