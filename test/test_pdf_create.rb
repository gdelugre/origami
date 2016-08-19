require 'minitest/autorun'
require 'stringio'

class TestPDFCreate < Minitest::Test

    def setup
        @output = StringIO.new
    end

    def test_pdf_create
        pdf = PDF.new

        null = Null.new
        pdf << null

        pdf.save(@output)

        assert null.indirect?
        assert_equal null.reference.solve, null
        assert pdf.root_objects.include?(null)
        assert_equal pdf.revisions.first.body[null.reference], null
        assert_equal null.reference.solve, null
    end
end
