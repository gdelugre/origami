#!/usr/bin/env ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, '../../lib')
    require 'origami'
end
include Origami

require 'stringio'

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"
EMBEDDED_NAME = "#{('a'..'z').to_a.sample(8).join}.pdf"

#
# Creates the nested document.
# A simple document displaying a message box.
#
output_str = StringIO.new
PDF.write(output_str) do |pdf|
    pdf.onDocumentOpen Action::JavaScript "app.alert('Hello world!');" 
end

output_str.rewind

# The envelope document.
pdf = PDF.new.append_page

# Create an object stream to compress objects.
objstm = ObjectStream.new
objstm.Filter = :FlateDecode

pdf.insert(objstm)

objstm.insert pdf.attach_file(output_str, register: true, name: EMBEDDED_NAME)

# Compress the page tree.
objstm.insert(pdf.Catalog.Pages)
objstm.insert(pdf.pages.first)

# Compress the name tree.
objstm.insert(pdf.Catalog.Names)
objstm.insert(pdf.Catalog.Names.EmbeddedFiles)

# Compress the catalog.
objstm.insert(pdf.Catalog)

pdf.pages.first.onOpen Action::GoToE[EMBEDDED_NAME]

pdf.save(OUTPUT_FILE, noindent: true)
