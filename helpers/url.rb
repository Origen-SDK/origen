module Origen
  class Generator
    class Compiler # :nodoc: all
      # Helper methods that are available to all templates
      module Helpers

        def self.archive_name=(val)
          @archive_name = val
        end

        def self.archive_name
          @archive_name
        end

        def generate_hard_links?
          !!archive_name
        end

        def archive_name
          Origen::Generator::Compiler::Helpers.archive_name
        end

        def current_path
          path(options[:top_level_file].to_s.sub(/^.*\/templates\/web/, '').sub(/\..*$/, ''))
        end

        def current_url
          "#{domain_minus_root_path}#{current_path}"
        end

        # Like current_url except always returns the latest version of the url and
        # not one with an embedded production version
        def current_latest_url
          current_url.sub(_archive, 'latest')
        end

        def path(p)
          p = "/#{p}" unless p =~ /^\//
          
          if Origen.development?
            "#{p}"   # dev mode used for local website generation
          # For Git deploy don't maintain versions
          elsif Origen.app.deployer.deploy_to_git?
            "#{root_path}#{p}"
          else          
            "#{root_path}/#{_archive}#{p}"
          end
        end

        def url(p)
          "#{domain_minus_root_path}#{path(p)}"
        end

        def domain
          Origen.config.web_domain
        end

        def domain_minus_root_path
          domain.sub /#{root_path}$/, ''
        end

        def _archive
          if generate_hard_links?
            archive_name.to_s.gsub(".", "_")
          else
            'latest'
          end
        end

        # Returns any path attached to the domain, for example will return "/jtag"
        # for "http://origen-sdk.org/jtag"
        def root_path # :nodoc:
          if domain =~ /\/\/[^\/]*(\/.*)/  # http://rubular.com/r/UY06Z6DXUS
            $1
          end
        end

      end
    end
  end
end
