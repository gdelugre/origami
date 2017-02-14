require 'minitest/autorun'

class TestPDFParser < Minitest::Test
    def setup
        @files =
            %w{
              dataset/empty.pdf
              dataset/calc.pdf
              dataset/crypto.pdf
              }

        @dict = StringScanner.new "<</Ref 2 0 R/N null/Pi 3.14 /D <<>>>>"

        @literalstring = StringScanner.new "(\\122\\125by\\n)"
        @hexastring = StringScanner.new "<52  55  62 79 0A>"
        @true = StringScanner.new "true"
        @false = StringScanner.new "false"
        @real = StringScanner.new "-3.141592653"
        @int = StringScanner.new "00000000002000000000000"
        @name = StringScanner.new "/#52#55#62#79#0A"
        @ref = StringScanner.new "199 1 R"
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
        dict = Dictionary.parse(@dict)

        assert_instance_of Dictionary, dict
        assert_instance_of Dictionary, dict[:D]
        assert_instance_of Null, dict[:N]
        assert_instance_of Reference, dict[:Ref]
        assert_raises(InvalidReferenceError) { dict[:Ref].solve }
        assert dict[:Pi] == 3.14
    end

    def test_parse_string
        str = LiteralString.parse(@literalstring)
        assert_instance_of LiteralString, str
        assert_equal str.value, "RUby\n"

        str = HexaString.parse(@hexastring)
        assert_instance_of HexaString, str
        assert_equal str.value, "RUby\n"
    end

    def test_parse_bool
        b_true = Boolean.parse(@true)
        b_false = Boolean.parse(@false)

        assert_instance_of Boolean, b_true
        assert_instance_of Boolean, b_false

        assert b_false.false?
        refute b_true.false?
    end

    def test_parse_real
        real = Real.parse(@real)
        assert_instance_of Real, real

        assert_equal real, -3.141592653
    end

    def test_parse_int
        int = Origami::Integer.parse(@int)
        assert_instance_of Origami::Integer, int

        assert_equal int, 2000000000000
    end

    def test_parse_name
        name = Name.parse(@name)
        assert_instance_of Name, name

        assert_equal name.value, :"RUby\n"
    end

    def test_parse_reference
        ref = Reference.parse(@ref)
        assert_instance_of Reference, ref

        assert_equal [199, 1], ref.to_a
        assert_raises(InvalidReferenceError) { ref.solve }
    end
end
