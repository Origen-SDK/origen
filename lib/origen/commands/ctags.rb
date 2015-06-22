puts 'Generating ctags file...'
# system("ctags -R --exclude='.ref/**,output/**' #{ORIGEN_WORK} #{ORIGEN_TOP}/lib")
Origen.load_application
if Origen.top == Origen.root
  system("ctags -R #{Origen.top}/lib -f #{Origen.root}/tags")
else
  system("ctags -R #{Origen.top}/lib #{Origen.root}/lib -f #{Origen.root}/tags")
end
puts 'Completed successfully'
