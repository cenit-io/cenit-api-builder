# frozen_string_literal: true

require_relative 'lib/cenit/api_builder/version'

Gem::Specification.new do |spec|
  spec.name = 'cenit-api_builder'
  spec.version = Cenit::ApiBuilder::VERSION
  spec.authors = ['Yoandry Pacheco Aguila']
  spec.email = ['yoandrypa@gmail.com']

  spec.summary = 'CenitIO API Builder'
  spec.description = 'Management API Builder for CenitIO from OpenAPI Specification'
  spec.homepage = 'https://github.com/cenit-io/cenit-api_builder'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.5.0'

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  # spec.bindir        = "exe"
  # spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'openapi3_parser','~> 0.9'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.7'

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
