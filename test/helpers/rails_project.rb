module CompassRails
  module Test
    class RailsProject
      include FileHelper
      include DebugHelper
      include CommandHelper
      include RailsHelpers
      include Kernal::Captures


      GEMFILE = 'Gemfile'
      GEMFILE_LOCK = 'Gemfile.lock'
      ENVIRONMENT = 'config/environment.rb'
      COMPASS_CONFIG = 'config/compass.rb'


      attr_reader :directory, :version

      def initialize(directory, version)
        @directory = Pathname.new(directory)
        @version = version
        configure_for_bundler!
      end

      ## FILE METHODS
        
      def to_s
        directory_name
      end

      def directory_name
        File.basename(directory)
      end

      def has_file?(file)
        File.exist? directory.join(file)
      end

      # RAILS METHDODS

      def has_generator?(name)
        rails_command(['g'], version).downcase.include?("#{name}:")
      end

      def boots?
        test_string = "THIS IS MY RANDOM AWESOME TEST STRING"
        matcher = %r{#{test_string}}
        case version
        when RAILS_3_1, RAILS_3
          rails_command(['runner', "'puts \"#{test_string}\"'"], version) =~ matcher
        when RAILS_2
          run_command("script/runner 'puts \"#{test_string}\"'", GEMFILES[version]) =~ matcher
        end
      end

      # SASS METHODS

      def has_sass_middleware?
        case version
        when RAILS_3_1, RAILS_3
        when RAILS_2
        end
      end

      # COMPASS METHODS

      def install_compass
        install_compass_gem
        touch directory.join(COMPASS_CONFIG)
        inject_at_bottom directory.join(COMPASS_CONFIG), <<-CONFIG
          project_type = :rails
        CONFIG
      end

      def run_compass(command)
        unless File.exist?(directory.join(GEMFILE_LOCK))
          bundle
        end
        run_command("compass #{command}", directory.join(GEMFILE))
      end

      def set_compass(property, value)
        file = directory.join(COMPASS_CONFIG)
        inject_at_bottom(file, "#{property} = #{value}")
      end

      ## GEM METHODS

      def configure_for_bundler!
        return if [RAILS_3_1, RAILS_3].include?(version)
        bundle = <<-BUNDLER
        class Rails::Boot
          def run
            load_initializer

            Rails::Initializer.class_eval do
              def load_gems
                @bundler_loaded ||= Bundler.require :default, Rails.env
              end
            end

            Rails::Initializer.run(:set_load_path)
          end
        end
        BUNDLER
        inject_into_file(directory.join('config/boot.rb'), bundle, :before, 'Rails.boot!')

        touch directory.join('config/preinitializer.rb')
        preinit = <<-PREINIT
          begin
            require "rubygems"
            require "bundler"
          rescue LoadError
            raise "Could not load the bundler gem. Install it with `gem install bundler`."
          end

          if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.24")
            raise RuntimeError, "Your bundler version is too old for Rails 2.3." +
             "Run `gem install bundler` to upgrade."
          end

          begin
            # Set up load paths for all bundled gems
            ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
            Bundler.setup
          rescue Bundler::GemNotFound
            raise RuntimeError, "Bundler couldn't find some gems." +
              "Did you run `bundle install`?"
          end
        PREINIT
        inject_at_bottom(directory.join('config/preinitializer.rb'), preinit)

        touch directory.join('Gemfile')
        install_gem 'rails', "'#{version}'"

      end

      def bundle!
        capture_output do
          `bundle install`
        end
      end

      def has_gem?(name)
        File.read(directory.join(GEMFILE)).include? "gem '#{name}'"
      end

      def install_gem(name, requirements=nil)
        add_to_gemfile(name, requirements)
      end

      def install_compass_gem
        install_gem('compass', "'~> 0.12.alpha'")
      end

    private

      ## GEM METHODS

      def add_to_environment(name, requirements)
        file = directory.join(ENVIRONMENT)
        debug("Adding gem #{name} to file: #{file}".foreground(:green))
        if requirements
          gem_string = "  config.gem '#{name}', :version => #{requirements}\n"
        else
          gem_string = "  config.gem '#{name}'\n"
        end
        inject_into_file(file, gem_string, :after, "Rails::Initializer.run do |config|")
      end

      def add_to_gemfile(name, requirements)
        gemfile = directory.join(GEMFILE)
        debug("Adding gem #{name} to file: #{gemfile}".foreground(:green))
        if requirements
          gem_string = "  gem '#{name}', #{requirements}\n"
        else
          gem_string = "  gem '#{name}'\n"
        end
        inject_at_bottom(gemfile, gem_string)
      end
    end
  end
end