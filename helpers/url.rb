module RGen
  class Generator
    class Compiler # :nodoc: all
      # Helper methods that are available to all templates
      module Helpers

        def current_path
          path(options[:top_level_file].to_s.sub(/^.*\/templates\/web/, '').sub(/\..*$/, ''))
        end

        def current_url
          "#{domain_minus_root_path}#{current_path}"
        end

        # Like current_url except always returns the latest version of the url and
        # not one with an embedded production version
        def current_latest_url
          current_url.sub(_version, 'latest')
        end

        def path(p)
          p = "/#{p}" unless p =~ /^\//
          
          if RGen.development?
            "#{p}"   # dev mode used for local website generation
          else          
            "#{root_path}/#{_version}#{p}"
          end
        end

        def url(p)
          "#{domain_minus_root_path}#{path(p)}"
        end

        def domain
          RGen.config.web_domain
        end

        def domain_minus_root_path
          domain.sub /#{root_path}$/, ''
        end

        def _version
          # Special case for RGen core..
          if RGen.top == RGen.root
            version = RGen.version
          else
            version = RGen.app.version
          end
          if version.development?
            'latest'
          else
            version.to_s.gsub(".", "_")
          end
        end

        # Returns any path attached to the domain, for example will return "/tfs"
        # for "http://rgen.freescale.net/tfs"
        def root_path # :nodoc:
          if domain =~ /\/\/[^\/]*(\/.*)/  # http://rubular.com/r/UY06Z6DXUS
            $1
          end
        end

      end
    end
  end
end
