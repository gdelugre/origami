require_relative 'lib/origami/version'

Gem::Specification.new do |s|
    s.name          = "origami"
    s.version       = Origami::VERSION
    s.author        = "Guillaume Delugré"
    s.email         = "origami@subvert.technology"
    s.homepage      = "http://github.com/gdelugre/origami"
    s.platform      = Gem::Platform::RUBY

    s.summary       = "Ruby framework to manipulate PDF documents"
    s.description   = "Origami is a pure Ruby library to parse, modify and generate PDF documents."

    s.files         = Dir[
                        'README.md',
                        'CHANGELOG.md',
                        'COPYING.LESSER',
                        "{lib,bin,test,examples}/**/*",
                        "bin/shell/.irbrc"
                    ]

    s.require_path  = "lib"
    s.test_file     = "test/test_pdf.rb"
    s.license       = "LGPL-3.0+"

    s.required_ruby_version = '>= 2.1'
    s.add_runtime_dependency "colorize", "~> 0.8"
    s.add_development_dependency "minitest", "~> 5.0"
    s.add_development_dependency 'rake',     '~> 10.0'
    s.add_development_dependency 'rdoc',     '~> 5.0'

    s.bindir        = "bin"
    s.executables   = %w(pdfsh
                         pdf2pdfa pdf2ruby
                         pdfcop pdfmetadata
                         pdfdecompress pdfdecrypt pdfencrypt
                         pdfexplode pdfextract)
end
