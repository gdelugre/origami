#!/usr/bin/ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, '.rb')}.pdf"
URL = "http://mydomain/calc.pdf"

pdf = PDF.new

contents = ContentStream.new
contents.write OUTPUT_FILE,
    x: 210, y: 750, rendering: Text::Rendering::FILL, size: 30

contents.write "When opened, this PDF connects to \"home\"",
    x: 156, y: 690, rendering: Text::Rendering::FILL, size: 15

contents.write "Click \"Allow\" to connect to #{URL} through your current Reader.",
    x: 106, y: 670, size: 12

contents.write "Comments:",
    x: 75, y: 600, rendering: Text::Rendering::FILL_AND_STROKE, size: 12

comment = <<-EOS
    Adobe Reader will render the PDF file returned by the remote server.
EOS

contents.write comment,
    x: 75, y: 580, rendering: Text::Rendering::FILL, size: 12

pdf.append_page Page.new.setContents(contents)

# Submit flags.
flags = Action::SubmitForm::Flags::EXPORTFORMAT|Action::SubmitForm::Flags::GETMETHOD

# Sends the form at the document opening.
pdf.onDocumentOpen Action::SubmitForm[URL, [], flags]

# Save the resulting file.
pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
