require 'minitest/autorun'
require 'strscan'

class TestPDFCreate < Minitest::Test
    using Origami::TypeConversion

    def test_type_string
        assert_kind_of Origami::String, "".to_o
        assert_kind_of ::String, "".to_o.value

        assert_equal "<616263>", HexaString.new("abc").to_s
        assert_equal "(test)", LiteralString.new("test").to_s
        assert_equal '(\(\(\(\)\)\)\))', LiteralString.new("((())))").to_s
        assert_equal "abc", "abc".to_s.to_o
    end

    def test_string_encoding
        str = LiteralString.new("test")

        assert_equal Origami::String::Encoding::PDFDocEncoding, str.encoding
        assert_equal "UTF-8", str.to_utf8.encoding.to_s

        assert_equal "\xFE\xFF\x00t\x00e\x00s\x00t".b, str.to_utf16be
        assert_equal Origami::String::Encoding::UTF16BE, str.to_utf16be.to_o.encoding
        assert_equal str, str.to_utf16be.to_o.to_pdfdoc
    end

    def test_type_null
        assert_instance_of Null, nil.to_o
        assert_nil Null.new.value
        assert_equal Null.new.to_s, "null"
    end

    def test_type_name
        assert_instance_of Name, :test.to_o
        assert_instance_of Symbol, :test.to_o.value

        assert_equal "/test", Name.new(:test).to_s
        assert_equal "/#20#23#09#0d#0a#00#5b#5d#3c#3e#28#29#25#2f", Name.new(" #\t\r\n\0[]<>()%/").to_s
        assert_equal " #\t\r\n\0[]<>()%/", Name.new(" #\t\r\n\0[]<>()%/").value.to_s
    end

    def test_type_boolean
        assert_instance_of Boolean, true.to_o
        assert_instance_of Boolean, false.to_o
        assert Boolean.new(true).value
        refute Boolean.new(false).value
        assert_equal "true", true.to_o.to_s
        assert_equal "false", false.to_o.to_s
    end

    def test_type_numeric
        assert_instance_of Origami::Real, Math::PI.to_o
        assert_instance_of Origami::Integer, 1.to_o

        assert_equal "1.8", Origami::Real.new(1.8).to_s
        assert_equal "100", Origami::Integer.new(100).to_s
        assert_equal 1.8, 1.8.to_o.value
        assert_equal 100, 100.to_o.value
    end

    def test_type_array
        array = [1, "a", [], {}, :test, nil, true, 3.14]

        assert_instance_of Origami::Array, [].to_o  
        assert_instance_of ::Array, [].to_o.value

        assert_equal array, array.to_o.value
        assert_equal "[1 (a) [] <<>> /test null true 3.14]", array.to_o.to_s
        assert array.to_o.all? {|o| o.is_a? Origami::Object} 
    end

    def test_type_dictionary
        assert_instance_of Origami::Dictionary, {}.to_o
        assert_instance_of Hash, {}.to_o.value

        dict = {a: 1, b: false, c: nil, d: "abc", e: :abc, f: []}

        assert_equal "<</a 1/b false/c null/d (abc)/e /abc/f []>>", dict.to_o.to_s(indent: 0)
        assert_equal dict, dict.to_o.value
        assert dict.to_o.all?{|k,v| k.is_a?(Name) and v.is_a?(Origami::Object)}
    end
end
