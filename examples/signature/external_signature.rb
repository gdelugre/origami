#!/usr/bin/ruby

require 'openssl'
require 'base64'

begin
  require 'origami'
rescue LoadError
  $: << File.join(__dir__, "../../lib")
  require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

# Create the PDF contents
contents = ContentStream.new.setFilter(:FlateDecode)
contents.write OUTPUT_FILE,
               x: 350, y: 750, size: 30

pdf  = PDF.new
page = Page.new.setContents(contents)
pdf.append_page(page)

puts "PDF created"
signable_content = pdf.prepare_signature(issuer: "Max Mustermann")

# you will probably need to base64 encode signable_content
sig = sign_with_external_provider(signable_content)

# insert computed signature value to pdf, it must be provided in DER format, so you will probable need to base64 decode it first
pdf.insert_signature(sig)

pdf.save(OUTPUT_FILE)
puts "PDF saved as " + OUTPUT_FILE
