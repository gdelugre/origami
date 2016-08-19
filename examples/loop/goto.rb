#!/usr/bin/env ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, '.rb')}.pdf"

pdf = PDF.new

50.times do |n|
    pdf.append_page do |page|
        contents = ContentStream.new
        contents.write "page #{n+1}",
            x: 250, y: 450, rendering: Text::Rendering::FILL, size: 30

        page.Contents = contents
    end
end

pages = pdf.pages
pages.each_with_index do |page, index|
    page.onOpen Action::GoTo Destination::GlobalFit[pages[(index + 1) % pages.size]]
end

pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
