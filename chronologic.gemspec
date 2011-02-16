## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'chronologic'
  s.version           = '0.7.6'
  s.date              = '2011-02-16'
  s.rubyforge_project = 'chronologic'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Chronologic is a database for activity feeds."
  s.description = "Chronologic uses Cassandra to fetch and store activity feeds. Quickly."

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["Adam Keys", "Scott Raymond"]
  s.email    = 'ak@gowalla.com'
  s.homepage = 'http://github.com/gowalla/chronologic'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  s.add_dependency('cassandra', ["~> 0.8.2"])
  s.add_dependency('httparty', ["~> 0.6.1"])
  s.add_dependency('hashie', ["~> 0.4.0"])
  s.add_dependency('will_paginate', ["~> 3.0.pre2"])
  s.add_dependency('hoptoad_notifier', ["~> 2.3.11"])

  ## List your development dependencies here. Development dependencies are
  ## those that are only needed during development
  s.add_development_dependency('minitest', ["~> 1.7.2"])
  s.add_development_dependency('rack-test', ["~> 0.5.6"])
  s.add_development_dependency('webmock', ['~> 1.5.0'])

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    Gemfile
    LICENSE
    README.md
    Rakefile
    chronologic.gemspec
    config.ru
    doc/intro.md
    examples/config.yml
    examples/gowalla.rb
    examples/gowalla_activerecord.rb
    examples/outings.rb
    examples/paginate.rb
    examples/twitter.rb
    init.rb
    lib/chronologic.rb
    lib/chronologic/client.rb
    lib/chronologic/event.rb
    lib/chronologic/feed.rb
    lib/chronologic/protocol.rb
    lib/chronologic/publisher.rb
    lib/chronologic/record.rb
    lib/chronologic/schema.rb
    lib/chronologic/service.rb
    lib/chronologic/subscriber.rb
    test/chronologic/test_client.rb
    test/chronologic/test_event.rb
    test/chronologic/test_feed.rb
    test/chronologic/test_protocol.rb
    test/chronologic/test_publisher.rb
    test/chronologic/test_record.rb
    test/chronologic/test_schema.rb
    test/chronologic/test_service.rb
    test/chronologic/test_subscriber.rb
    test/helper.rb
    test/storage-conf.xml
    test/test_chronologic.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
