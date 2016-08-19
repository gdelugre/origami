#!/usr/bin/ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, '.rb')}.pdf"
URL = "http://google.fr"

pdf = PDF.new

# Trigger an URI action when the document is opened.
pdf.onDocumentOpen Action::URI[URL]

pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
