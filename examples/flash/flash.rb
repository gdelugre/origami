#!/usr/bin/env ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

#
# Embeding a Flash asset inside a PDF document.
#

SWF_PATH = File.join(__dir__, "helloworld.swf")
OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

# Creating a new file
pdf = PDF.new

# Embedding the SWF file into the PDF.
swf = pdf.attach_file(SWF_PATH)

# Creating a Flash annotation on the page.
pdf.append_page do |page|
    annot = page.add_flash_application(swf,
                                       windowed: true,
                                       navigation_pane: true,
                                       toolbar: true)

    # Setting the player position on the page.
    annot.Rect = Rectangle.new [204, 573, 403, 718]
end

pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
