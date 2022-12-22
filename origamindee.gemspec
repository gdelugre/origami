# frozen_string_literal: true

require_relative 'lib/origami/version'

Gem::Specification.new do |spec|
    spec.name          = 'origamindee'
    spec.version       = Origami::VERSION
    spec.authors       = ['Guillaume Delugré', 'Mindee, SA']
    spec.email         = 'devrel@mindee.co'
    spec.homepage      = 'https://github.com/mindee/origamindee'
    spec.platform      = Gem::Platform::RUBY

    spec.summary       = 'Ruby framework to manipulate PDF documents'
    spec.description   = "Mindee's fork of Origami, a pure Ruby library to parse, modify and generate PDF documents."

    spec.files         = Dir[
                        'README.md',
                        'CHANGELOG.md',
                        'COPYING.LESSER',
                        "{lib,bin,test,examples}/**/*",
                        'bin/shell/.irbrc',
                    ]

    spec.require_path  = 'lib'
    spec.test_file     = 'test/test_pdf.rb'
    spec.license       = 'LGPL-3.0+'

    spec.required_ruby_version = '>= 2.6'
    spec.add_runtime_dependency 'colorize', '~> 0.8'
    spec.add_development_dependency 'minitest', '~> 5.0'
    spec.add_development_dependency 'rake',     '~> 10.0'
    spec.add_development_dependency 'rdoc',     '~> 5.0'

    spec.bindir        = 'bin'
    spec.executables   = %w(pdfsh
                         pdf2pdfa pdf2ruby
                         pdfcop pdfmetadata
                         pdfdecompress pdfdecrypt pdfencrypt
                         pdfexplode pdfextract)
end
