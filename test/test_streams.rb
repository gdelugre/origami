require 'minitest/autorun'
require 'stringio'

class TestStreams < Minitest::Test
    def setup
        @target = PDF.new
        @output = StringIO.new
        @data = "0123456789" * 1024
    end

    def test_predictors
        stm = Stream.new(@data, :Filter => :FlateDecode)
        stm.set_predictor(Filter::Predictor::TIFF)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal @data, stm.data

        stm = Stream.new(@data, :Filter => :FlateDecode)
        stm.set_predictor(Filter::Predictor::PNG_SUB)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal @data, stm.data

        stm = Stream.new(@data, :Filter => :FlateDecode)
        stm.set_predictor(Filter::Predictor::PNG_UP)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        stm = Stream.new(@data, :Filter => :FlateDecode)
        stm.set_predictor(Filter::Predictor::PNG_AVERAGE)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        stm = Stream.new(@data, :Filter => :FlateDecode)
        stm.set_predictor(Filter::Predictor::PNG_PAETH)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data
    end

    def test_filter_flate
        stm = Stream.new(@data, :Filter => :FlateDecode)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        assert_equal Filter::Flate.decode(Filter::Flate.encode("")), ""
    end

    def test_filter_asciihex
        stm = Stream.new(@data, :Filter => :ASCIIHexDecode)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        assert_raises(Filter::InvalidASCIIHexStringError) do
            Filter::ASCIIHex.decode("123456789ABCDEFGHIJKL")
        end

        assert_equal Filter::ASCIIHex.decode(Filter::ASCIIHex.encode("")), ""
    end

    def test_filter_ascii85
        stm = Stream.new(@data, :Filter => :ASCII85Decode)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        assert_raises(Filter::InvalidASCII85StringError) do
            Filter::ASCII85.decode("ABCD\x01")
        end

        assert_equal Filter::ASCII85.decode(Filter::ASCII85.encode("")), ""
    end

    def test_filter_rle
        stm = Stream.new(@data, :Filter => :RunLengthDecode)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        assert_raises(Filter::InvalidRunLengthDataError) do
            Filter::RunLength.decode("\x7f")
        end

        assert_equal Filter::RunLength.decode(Filter::RunLength.encode("")), ""
    end

    def test_filter_lzw
        stm = Stream.new(@data, :Filter => :LZWDecode)
        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data

        assert_raises(Filter::InvalidLZWDataError) do
            Filter::LZW.decode("abcd")
        end

        assert_equal Filter::LZW.decode(Filter::LZW.encode("")), ""
    end

    def test_filter_ccittfax
        stm = Stream.new(@data[0, 216], :Filter => :CCITTFaxDecode)

        raw = stm.encoded_data
        stm.data = nil
        stm.encoded_data = raw

        assert_equal stm.data, @data[0, 216]

        assert_raises(Filter::InvalidCCITTFaxDataError) do
            Filter::CCITTFax.decode("abcd")
        end

        assert_equal Filter::CCITTFax.decode(Filter::CCITTFax.encode("")), ""
    end

    def test_stream
        chain = %i[FlateDecode LZWDecode ASCIIHexDecode]

        stm = Stream.new(@data, Filter: chain)
        @target << stm
        @target.save(@output)

        assert stm.Length == stm.encoded_data.length
        assert_equal stm.filters, chain
        assert_equal stm.data, @data
    end

    def test_object_stream
        objstm = ObjectStream.new
        objstm.Filter = %i[FlateDecode ASCIIHexDecode RunLengthDecode]

        @target << objstm

        assert_raises(InvalidObjectError) do
            objstm.insert Stream.new
        end

        3.times do
            objstm.insert HexaString.new(@data)
        end

        assert_equal objstm.objects.size, 3

        objstm.each_object do |object|
            assert_instance_of HexaString, object
            assert_equal object.parent, objstm
            assert objstm.include?(object.no)
            assert_equal objstm.extract(object.no), object
            assert_equal objstm.extract_by_index(objstm.index(object.no)), object
        end

        objstm.delete(objstm.objects.first.no)
        assert_equal objstm.objects.size, 2

        @target.save(@output)

        assert_instance_of Origami::Integer, objstm.N
        assert_equal objstm.N, objstm.objects.size
    end
end
