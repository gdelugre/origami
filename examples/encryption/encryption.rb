#!/usr/bin/env ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

#
# Encrypts a document with an empty password.
#

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

# Creates an encrypted document with AES256 and a null password.
pdf = PDF.new.encrypt(cipher: 'aes', key_size: 256)

contents = ContentStream.new
contents.write "Encrypted document sample",
    x: 100, y: 750, rendering: Text::Rendering::STROKE, size: 30

pdf.append_page Page.new.setContents(contents)

pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
