class Origen::Generator::Compiler

  def origen_core_frontmatter(options={})
<<END    
analytics: UA-64455560-1
url: #{current_url}
facebook: origensdk
twitter: origensdk
author_url: https://plus.google.com/u/1/b/106463981272125989995/106463981272125989 
site_name: Origen - The Semiconductor Developer's Kit
gitter_chat: Origen-SDK/users
END
  end

end
