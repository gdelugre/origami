require 'minitest/autorun'
require 'stringio'

class TestPDFLazyParser < Minitest::Test

    def setup
        @files = 
            %w{
              dataset/empty.pdf
              dataset/calc.pdf
              dataset/crypto.pdf
              }

    end

    def test_parse_pdf_lazy
        @files.each do |file|
            pdf = PDF.read(File.join(__dir__, file), 
                           ignore_errors: false,
                           lazy: true,
                           verbosity: Parser::VERBOSE_QUIET)

            assert_instance_of PDF, pdf

            pdf.each_object do |object|
                assert_kind_of Origami::Object, object
            end

            assert_instance_of Catalog, pdf.Catalog

            pdf.each_page do |page|
                assert_kind_of Page, page
            end
        end
    end

    def test_save_pdf_lazy
        @files.each do |file|
            pdf = PDF.read(File.join(__dir__, file), 
                           ignore_errors: false,
                           lazy: true,
                           verbosity: Parser::VERBOSE_QUIET)

            pdf.save(StringIO.new)
        end
    end

    def test_random_access
        io = StringIO.new
        stream = Stream.new("abc")

        PDF.create(io) do |pdf|
            pdf.insert(stream)
        end

        io = io.reopen(io.string, 'r')

        pdf = PDF.read(io, ignore_errors: false,
                           lazy: true,
                           verbosity: Parser::VERBOSE_QUIET)

        non_existent = pdf[42]
        existent = pdf[stream.reference]

        assert_nil non_existent
        assert_instance_of Stream, existent
        assert_equal stream.data, existent.data
    end
end
