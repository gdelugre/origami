#!/usr/bin/ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

#
# Interactive JavaScript interpreter using an Acrobat Form.
#

require 'origami/template/widgets'

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

pdf = PDF.new.append_page(page = Page.new)

contents = ContentStream.new.setFilter(:FlateDecode)

contents.write "Write your JavaScript below and run it",
    x: 100, y: 750, size: 24, rendering: Text::Rendering::FILL,
    fill_color: Graphics::Color::RGB.new(0xFF, 0x80, 0x80)

contents.write "You need at least Acrobat Reader 8 to use this document.",
    x: 50, y: 80, size: 12, rendering: Text::Rendering::FILL

contents.write "\nGenerated with Origami #{Origami::VERSION}.",
    color: Graphics::Color::RGB.new(0, 0, 255)

contents.draw_rectangle(45, 35, 320, 60,
                        line_width: 2.0, dash: Graphics::DashPattern.new([3]),
                        fill: false, stroke: true, stroke_color: Graphics::Color::GrayScale.new(0.7))

page.Contents = contents

ml = Template::MultiLineEdit.new('scriptedit', x: 50, y: 280, width: 500, height: 400)
ml.V = <<JS
console.show();
console.println('Script entry point');
app.alert("Hello");
JS

button = Template::Button.new("Run!", x: 490, y: 240, width: 60, height: 30)
button.onActivate Action::JavaScript["eval(this.getField('scriptedit').value);"]

page.add_annotation(ml, button)
pdf.create_form(button, ml)

pdf.save(OUTPUT_FILE, noindent: true)

puts "PDF file saved as #{OUTPUT_FILE}."
