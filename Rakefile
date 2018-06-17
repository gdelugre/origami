# encoding: UTF-8

# Optionally install bundler tasks if present.
begin
    require 'bundler'

    Bundler.setup
    Bundler::GemHelper.install_tasks
rescue LoadError
end

require 'rdoc/task'
require 'rake/testtask'
require 'rake/clean'

desc "Generate rdoc documentation"
Rake::RDocTask.new("rdoc") do |rdoc|
    rdoc.rdoc_dir = "doc"
    rdoc.title = "Origami"
    rdoc.options << "-U" << "-N"
    rdoc.options << "-m" << "Origami::PDF"

    rdoc.rdoc_files.include("lib/origami/**/*.rb")
end

desc "Run the test suite"
Rake::TestTask.new do |t|
    t.verbose = true
    t.libs << "test"
    t.test_files = [ "test/test_pdf.rb" ]
end

task :clean do
    Rake::Cleaner.cleanup_files Dir['*.gem', 'doc', 'examples/**/*.pdf']
end

task :default => :test
