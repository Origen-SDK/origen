puts 'Generating ctags file...'
# system("ctags -R --exclude='.ref/**,output/**' #{RGEN_WORK} #{RGEN_TOP}/lib")
RGen.load_application
if RGen.top == RGen.root
  system("ctags -R #{RGen.top}/lib -f #{RGen.root}/tags")
else
  system("ctags -R #{RGen.top}/lib #{RGen.root}/lib -f #{RGen.root}/tags")
end
puts 'Completed successfully'
