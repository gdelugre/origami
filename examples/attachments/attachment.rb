#!/usr/bin/env ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

# Creating a new file
pdf = PDF.new

# Embedding the file into the PDF.
pdf.attach_file(DATA,
    name: "README.txt",
    filter: :ASCIIHexDecode
)

contents = ContentStream.new
contents.write "File attachment sample",
    x: 150, y: 750, rendering: Text::Rendering::FILL, size: 30

pdf.append_page Page.new.setContents(contents)

pdf.onDocumentOpen Action::JavaScript <<JS
    this.exportDataObject({cName:"README.txt", nLaunch:2});
JS


pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."

__END__
This is the attached file contents.
