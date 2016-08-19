#!/usr/bin/ruby

require 'openssl'

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

puts "Generating a RSA key pair."
key = OpenSSL::PKey::RSA.new 2048

puts "Generating a self-signed certificate."
name = OpenSSL::X509::Name.parse 'CN=origami/DC=example'

cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 0
cert.not_before = Time.now
cert.not_after = Time.now + 3600

cert.public_key = key.public_key
cert.subject = name

extension_factory = OpenSSL::X509::ExtensionFactory.new nil, cert

cert.add_extension extension_factory.create_extension('basicConstraints', 'CA:TRUE', true)
cert.add_extension extension_factory.create_extension('keyUsage', 'digitalSignature')
cert.add_extension extension_factory.create_extension('subjectKeyIdentifier', 'hash')

cert.issuer = name
cert.sign key, OpenSSL::Digest::SHA256.new

# Create the PDF contents
contents = ContentStream.new.setFilter(:FlateDecode)
contents.write OUTPUT_FILE,
    x: 350, y: 750, rendering: Text::Rendering::STROKE, size: 30

pdf = PDF.new
page = Page.new.setContents(contents)
pdf.append_page(page)

sig_annot = Annotation::Widget::Signature.new
sig_annot.Rect = Rectangle[llx: 89.0, lly: 386.0, urx: 190.0, ury: 353.0]

page.add_annotation(sig_annot)

# Sign the PDF with the specified keys
pdf.sign(cert, key,
    method: 'adbe.pkcs7.detached',
    annotation: sig_annot,
    location: "France",
    contact: "gdelugre@localhost",
    reason: "Signature sample"
)

# Save the resulting file
pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
