require 'minitest/autorun'

class TestPDFParser < Minitest::Test
    def setup
        @files =
            %w{
              dataset/empty.pdf
              dataset/calc.pdf
              dataset/crypto.pdf
              }
    end

    def test_parse_pdf
        @files.each do |file|
            pdf = PDF.read(File.join(__dir__, file), ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

            assert_instance_of PDF, pdf

            pdf.each_object do |object|
                assert_kind_of Origami::Object, object
            end
        end
    end

    def test_parse_dictionary
        dict = Dictionary.parse("<</Ref 2 0 R/N null/Pi 3.14 /D <<>>>>")

        assert_instance_of Dictionary, dict
        assert_instance_of Dictionary, dict[:D]
        assert_instance_of Null, dict[:N]
        assert_instance_of Reference, dict[:Ref]
        assert_equal dict.size, 4
        assert_raises(InvalidReferenceError) { dict[:Ref].solve }
        assert dict[:Pi] == 3.14
    end

    def test_parse_array
        array = Origami::Array.parse("[/Test (abc) .2 \n 799 [<<>>]]")

        assert array.all?{|e| e.is_a?(Origami::Object)}
        assert_equal array.length, 5
        assert_raises(InvalidArrayObjectError) { Origami::Array.parse("[1 ") }
        assert_raises(InvalidArrayObjectError) { Origami::Array.parse("") }
    end

    def test_parse_string
        str = LiteralString.parse("(\\122\\125by\\n)")
        assert_instance_of LiteralString, str
        assert_equal str.value, "RUby\n"

        assert_raises(InvalidLiteralStringObjectError) { LiteralString.parse("") }
        assert_raises(InvalidLiteralStringObjectError) { LiteralString.parse("(test") }
        assert_equal "((O))", LiteralString.parse("(((O)))").value
        assert_equal LiteralString.parse("(ABC\\\nDEF\\\r\nGHI)").value, "ABCDEFGHI"
        assert_equal LiteralString.parse('(\r\n\b\t\f\\(\\)\\x\\\\)').value, "\r\n\b\t\f()x\\"
        assert_equal LiteralString.parse('(\r\n\b\t\f\\\\\\(\\))').to_s, '(\r\n\b\t\f\\\\\\(\\))'

        str = HexaString.parse("<52  55  62 79 0A>")
        assert_instance_of HexaString, str
        assert_equal str.value, "RUby\n"

        assert_equal HexaString.parse("<4>").value, 0x40.chr

        assert_raises(InvalidHexaStringObjectError) { HexaString.parse("") }
        assert_raises(InvalidHexaStringObjectError) { HexaString.parse("<12") }
        assert_raises(InvalidHexaStringObjectError) { HexaString.parse("<12X>") }
    end

    def test_parse_bool
        b_true = Boolean.parse("true")
        b_false = Boolean.parse("false")

        assert_instance_of Boolean, b_true
        assert_instance_of Boolean, b_false

        assert b_false.false?
        refute b_true.false?

        assert_raises(InvalidBooleanObjectError) { Boolean.parse("") }
        assert_raises(InvalidBooleanObjectError) { Boolean.parse("tru") }
    end

    def test_parse_real
        real = Real.parse("-3.141592653")
        assert_instance_of Real, real
        assert_equal real, -3.141592653

        real = Real.parse("+.00200")
        assert_instance_of Real, real
        assert_equal real, 0.002

        assert_raises(InvalidRealObjectError) { Real.parse("") }
        assert_raises(InvalidRealObjectError) { Real.parse(".") }
        assert_raises(InvalidRealObjectError) { Real.parse("+0x1") }
    end

    def test_parse_int
        int = Origami::Integer.parse("02000000000000")
        assert_instance_of Origami::Integer, int
        assert_equal int, 2000000000000

        int = Origami::Integer.parse("-98")
        assert_instance_of Origami::Integer, int
        assert_equal int, -98

        assert_raises(Origami::InvalidIntegerObjectError) { Origami::Integer.parse("") }
        assert_raises(Origami::InvalidIntegerObjectError) { Origami::Integer.parse("+-1") }
        assert_raises(Origami::InvalidIntegerObjectError) { Origami::Integer.parse("ABC") }
    end

    def test_parse_name
        name = Name.parse("/#52#55#62#79#0A")
        assert_instance_of Name, name
        assert_equal name.value, :"RUby\n"

        name = Name.parse("/")
        assert_instance_of Name, name
        assert_equal :"", name.value

        assert_raises(Origami::InvalidNameObjectError) { Name.parse("") }
        assert_raises(Origami::InvalidNameObjectError) { Name.parse("test") }
    end

    def test_parse_reference
        ref = Reference.parse("199 1 R")
        assert_instance_of Reference, ref

        assert_equal [199, 1], ref.to_a
        assert_raises(InvalidReferenceError) { ref.solve }
        assert_raises(InvalidReferenceError) { Reference.parse("-2 0 R") }
        assert_raises(InvalidReferenceError) { Reference.parse("0 R") }
        assert_raises(InvalidReferenceError) { Reference.parse("") }
    end
end
