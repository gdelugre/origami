require 'minitest/autorun'
require 'stringio'
require 'openssl'

class TestSign < Minitest::Test

    def setup
        @target = PDF.read(File.join(__dir__, "dataset/calc.pdf"),
                           ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)
        @output = StringIO.new

        @key = OpenSSL::PKey::RSA.new 2048

        name = OpenSSL::X509::Name.parse 'CN=origami/DC=example'

        @cert = OpenSSL::X509::Certificate.new
        @cert.version = 2
        @cert.serial = 0
        @cert.not_before = Time.now
        @cert.not_after = Time.now + 3600

        @cert.public_key = @key.public_key
        @cert.subject = name

        extension_factory = OpenSSL::X509::ExtensionFactory.new nil, @cert

        @cert.add_extension extension_factory.create_extension('basicConstraints', 'CA:TRUE', true)
        @cert.add_extension extension_factory.create_extension('keyUsage', 'digitalSignature')
        @cert.add_extension extension_factory.create_extension('subjectKeyIdentifier', 'hash')

        @cert.issuer = name
        @cert.sign @key, OpenSSL::Digest::SHA256.new
    end

    def test_sign
        sig_annot = Annotation::Widget::Signature.new.set_indirect(true)
        sig_annot.Rect = Rectangle[llx: 89.0, lly: 386.0, urx: 190.0, ury: 353.0]

        @target.append_page do |page|
            page.add_annotation(sig_annot)
        end

        @target.sign(@cert, @key,
            annotation: sig_annot,
            issuer: "Guillaume Delugré",
            location: "France",
            contact: "origami@localhost",
            reason: "Example"
        )

        assert @target.frozen?
        assert @target.signed?

        @target.save(@output)

        assert PDF.read(@output.reopen(@output.string,'r'), verbosity: Parser::VERBOSE_QUIET).verify
    end
end
