require 'minitest/autorun'
require 'stringio'

class TestPDFObjectTree < Minitest::Test

    def setup
        @pdf = PDF.new.append_page
        @contents = ContentStream.new("abc")
        @pdf.pages.first.Contents = @contents
        @pdf.Catalog.Loop = @pdf.Catalog
        @pdf.save StringIO.new
    end

    def test_pdf_object_tree
        assert_instance_of Catalog, @pdf.Catalog
        assert_nil @pdf.Catalog.parent

        @pdf.each_object(recursive: true) do |obj|
            assert_kind_of Origami::Object, obj
            assert_equal obj.document, @pdf

            unless obj.indirect?
                assert_kind_of Origami::Object, obj.parent
                assert_equal obj.parent.document, @pdf
            end
        end

        enum = @pdf.each_object(recursive: true)
        assert_kind_of Enumerator, enum
        assert enum.include?(@pdf.Catalog.Pages)
        assert enum.include?(@contents.dictionary)
    end
end
