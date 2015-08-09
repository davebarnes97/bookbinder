require 'middleman-core'
require 'middleman-core/cli'
require 'middleman-core/profiling'
require_relative 'code_example_reader'

class Middleman::Cli::BuildAction
  def handle_error(file_name, response, e=Thor::Error.new(response))
    our_errors = [Bookbinder::CodeExampleReader::InvalidSnippet,
                  QuicklinksRenderer::BadHeadingLevelError,
                  Git::GitExecuteError]
    raise e if our_errors.include?(e.class)

    original_handle_error(e, file_name, response)
  end

  private

  def original_handle_error(e, file_name, response)
    base.had_errors = true

    base.say_status :error, file_name, :red
    if base.debugging
      raise e
      exit(1)
    elsif base.options["verbose"]
      base.shell.say response, :red
    end
  end
end

module Bookbinder
  class MiddlemanRunner
    def initialize(logger)
      @logger = logger
    end

    def run(output_locations,
            config,
            local_repo_dir,
            verbose = false,
            subnav_templates_by_directory = {})
      @logger.log "\nRunning middleman...\n\n"

      within(output_locations.master_dir) do
        builder = Middleman::Cli::Build.shared_instance(verbose)

        config = {
          # Bookbinder config (serializable)
          archive_menu: config.archive_menu,
          production_host: config.public_host,
          subnav_templates: subnav_templates_by_directory,
          template_variables: config.template_variables,
          local_repo_dir: local_repo_dir,
          workspace: output_locations.workspace_dir,

          # Middleman config (serializable)
          relative_links: false,
        }

        config.each { |k, v| builder.config[k] = v }
        Middleman::Cli::Build.new([], {quiet: !verbose}, {}).invoke :build, [], {verbose: verbose}
      end
    end

    private

    def within(temp_root, &block)
      Middleman::Cli::Build.instance_variable_set(:@_shared_instance, nil)
      original_mm_root  = ENV['MM_ROOT']
      ENV['MM_ROOT']    = temp_root.to_s

      Dir.chdir(temp_root) { block.call }

      ENV['MM_ROOT']    = original_mm_root
    end
  end
end
