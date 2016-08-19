require 'minitest/autorun'
require 'stringio'

class TestEncryption < Minitest::Test
    def setup
        @target = PDF.read(File.join(__dir__, "dataset/calc.pdf"),
                           ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)
        @output = StringIO.new
    end

    def test_encrypt_rc4_40b
        @output.string = ""
        @target.encrypt(cipher: 'rc4', key_size: 40).save(@output)
    end

    def test_encrypt_rc4_128b
        @output.string = ""
        @target.encrypt(cipher: 'rc4').save(@output)
    end

    def test_encrypt_aes_128b
        @output.string = ""
        @target.encrypt(cipher: 'aes').save(@output)
    end

    def test_decrypt_rc4_40b
        @output.string = ""

        pdf = PDF.new.encrypt(cipher: 'rc4', key_size: 40)
        pdf.Catalog[:Test] = "test"
        pdf.save(@output)

        refute_equal pdf.Catalog[:Test], "test"

        @output = @output.reopen(@output.string, "r")
        pdf = PDF.read(@output, ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

        assert_equal pdf.Catalog[:Test], "test"
    end

    def test_decrypt_rc4_128b
        @output.string = ""
        pdf = PDF.new.encrypt(cipher: 'rc4')
        pdf.Catalog[:Test] = "test"
        pdf.save(@output)

        refute_equal pdf.Catalog[:Test], "test"

        @output.reopen(@output.string, "r")
        pdf = PDF.read(@output, ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

        assert_equal pdf.Catalog[:Test], "test"
    end

    def test_decrypt_aes_128b
        @output.string = ""
        pdf = PDF.new.encrypt(cipher: 'aes')
        pdf.Catalog[:Test] = "test"
        pdf.save(@output)

        refute_equal pdf.Catalog[:Test], "test"

        @output = @output.reopen(@output.string, "r")
        pdf = PDF.read(@output, ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

        assert_equal pdf.Catalog[:Test], "test"
    end

    def test_decrypt_aes_256b
        @output.string = ""
        pdf = PDF.new.encrypt(cipher: 'aes', key_size: 256)
        pdf.Catalog[:Test] = "test"
        pdf.save(@output)

        refute_equal pdf.Catalog[:Test], "test"

        @output = @output.reopen(@output.string, "r")
        pdf = PDF.read(@output, ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

        assert_equal pdf.Catalog[:Test], "test"
    end

    def test_crypt_filter
        @output.string = ""
        pdf = PDF.new.encrypt(cipher: 'aes', key_size: 128)

        pdf.Catalog[:S1] = Stream.new("test", :Filter => :Crypt)
        pdf.Catalog[:S2] = Stream.new("test")

        pdf.save(@output)

        assert_equal pdf.Catalog.S1.encoded_data, "test"
        refute_equal pdf.Catalog.S2.encoded_data, "test"
    end
end
