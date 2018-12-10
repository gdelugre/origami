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

# Create the PDF contents
contents = ContentStream.new.setFilter(:FlateDecode)
contents.write OUTPUT_FILE,
               x: 350, y: 750, size: 30

pdf = PDF.new
page = Page.new.setContents(contents)
pdf.append_page(page)

puts "PDF created"
pdf_b64 = pdf.prepare_signature(name: "Max Mustermann")
puts "Send this to your external signer: "
puts "------------------------------------------"
puts pdf_b64
puts "------------------------------------------"
puts "Update the signature file (signature.txt) and press enter"
gets

sig = IO.read("signature.txt")

puts "Inserting the signature into the PDF"
pdf.insert_signature sig

pdf.save(OUTPUT_FILE)
puts "PDF saved as " + OUTPUT_FILE
puts "Signature Check: http://signaturpruefung.gv.at/"
