require 'minitest/autorun'
require 'stringio'

class TestAttachment < Minitest::Test
    def setup
        @target = PDF.new
        @attachment = StringIO.new("test")
        @output = StringIO.new
    end

    def test_attach_file
        @target.attach_file(@attachment, name: "foo.bar", filter: :A85)

        @target.save(@output)

        @output = @output.reopen(@output.string, "r")
        pdf = PDF.read(@output, ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

        assert_equal pdf.each_named_embedded_file.count, 1
        assert_equal pdf.get_embedded_file_by_name("foo.baz"), nil

        file = pdf.get_embedded_file_by_name('foo.bar')
        refute_equal file, nil

        assert file.key?(:EF)
        assert file.EF.key?(:F)

        stream = file.EF.F
        assert stream.is_a?(Stream)

        assert_equal stream.dictionary.Filter, :A85
        assert_equal stream.data, "test"
    end
end
