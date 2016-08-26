require 'minitest/autorun'
require 'stringio'
require 'strscan'

class TestXrefs < MiniTest::Test

    def setup
        @target = PDF.new
    end

    def test_xreftable
        output = StringIO.new

        @target.save(output)
        output.reopen(output.string, 'r')

        pdf = PDF.read(output, verbosity: Parser::VERBOSE_QUIET, ignore_errors: false)

        xreftable = pdf.revisions.last.xreftable
        assert_instance_of XRef::Section, xreftable

        pdf.root_objects.each do |object|
            xref = xreftable.find(object.no)

            assert_instance_of XRef, xref
            assert xref.used?

            assert_equal xref.offset, object.file_offset
        end
    end

    def test_xrefstream
        output = StringIO.new
        objstm = ObjectStream.new
        objstm.Filter = :FlateDecode

        @target.insert objstm

        3.times do
            objstm.insert Null.new
        end

        @target.save(output)
        output = output.reopen(output.string, 'r')

        pdf = PDF.read(output, verbosity: Parser::VERBOSE_QUIET, ignore_errors: false)
        xrefstm = pdf.revisions.last.xrefstm

        assert_instance_of XRefStream, xrefstm
        assert xrefstm.entries.all?{ |xref| xref.is_a?(XRef) or xref.is_a?(XRefToCompressedObject) }

        pdf.each_object(compressed: true) do |object|
            xref = xrefstm.find(object.no)

            if object.parent.is_a?(ObjectStream)
                assert_instance_of XRefToCompressedObject, xref
                assert_equal xref.objstmno, object.parent.no
                assert_equal xref.index, object.parent.index(object.no)
            else
                assert_instance_of XRef, xref
                assert_equal xref.offset, object.file_offset
            end
        end

        assert_instance_of Catalog, xrefstm.Root
    end
end
