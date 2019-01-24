require 'minitest/autorun'
require 'stringio'
require 'openssl'

class TestSign < Minitest::Test

    def create_self_signed_ca_certificate(key_size, expires)
        key = OpenSSL::PKey::RSA.new key_size

        name = OpenSSL::X509::Name.parse 'CN=origami/DC=example'

        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.serial = 0
        cert.not_before = Time.now
        cert.not_after = Time.now + expires

        cert.public_key = key.public_key
        cert.subject = name

        extension_factory = OpenSSL::X509::ExtensionFactory.new
        extension_factory.issuer_certificate = cert
        extension_factory.subject_certificate = cert

        cert.add_extension extension_factory.create_extension('basicConstraints', 'CA:TRUE', true)
        cert.add_extension extension_factory.create_extension('keyUsage', 'digitalSignature,keyCertSign')
        cert.add_extension extension_factory.create_extension('subjectKeyIdentifier', 'hash')

        cert.issuer = name
        cert.sign key, OpenSSL::Digest::SHA256.new

        [ cert, key ]
    end

    def setup
        @cert, @key = create_self_signed_ca_certificate(1024, 3600)
        @other_cert, @other_key = create_self_signed_ca_certificate(1024, 3600)
    end

    def setup_document_with_annotation
        document = PDF.read(File.join(__dir__, "dataset/calc.pdf"),
                           ignore_errors: false, verbosity: Parser::VERBOSE_QUIET)

        annotation = Annotation::Widget::Signature.new.set_indirect(true)
        annotation.Rect = Rectangle[llx: 89.0, lly: 386.0, urx: 190.0, ury: 353.0]

        document.append_page do |page|
            page.add_annotation(annotation)
        end

        [ document, annotation ]
    end

    def sign_document_with_method(method)
        document, annotation = setup_document_with_annotation

        document.sign(@cert, @key,
            method: method,
            annotation: annotation,
            issuer: "Guillaume Delugré",
            location: "France",
            contact: "origami@localhost",
            reason: "Example"
        )

        assert document.frozen?
        assert document.signed?

        output = StringIO.new
        document.save(output)

        document = PDF.read(output.reopen(output.string,'r'), verbosity: Parser::VERBOSE_QUIET)

        refute document.verify
        assert document.verify(allow_self_signed: true)
        assert document.verify(trusted_certs: [@cert])
        refute document.verify(trusted_certs: [@other_cert])

        result = document.verify do |ctx|
            ctx.error == OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT and ctx.current_cert.to_pem == @cert.to_pem
        end

        assert result
    end

    def test_sign_pkcs7_sha1
        sign_document_with_method(Signature::PKCS7_SHA1)
    end

    def test_sign_pkcs7_detached
        sign_document_with_method(Signature::PKCS7_DETACHED)
    end

    def test_sign_x509_sha1
        sign_document_with_method(Signature::PKCS1_RSA_SHA1)
    end
end
