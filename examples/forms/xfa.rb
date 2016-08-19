#!/usr/bin/ruby 

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

require 'origami/template/widgets'

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

#
# Interactive FormCalc interpreter using a XFA form.
#

#
# XDP Packet holding the Form.
#
class SampleXDP < XDP::Package
    def initialize(script = "")
        super()

        self.root.add_element(create_config_packet)
        self.root.add_element(create_template_packet(script))
        self.root.add_element(create_datasets_packet)
    end

    def create_config_packet
        config = XDP::Packet::Config.new

        present = config.add_element(XFA::Element.new("present"))
        pdf = present.add_element(XFA::Element.new("pdf"))
        interactive = pdf.add_element(XFA::Element.new("interactive"))
        interactive.text = 1

        config
    end

    def create_template_packet(script)
        template = XDP::Packet::Template.new

        form1 = template.add_subform(layout: 'tb', name: 'form1')
        form1.add_pageSet
        form1.add_event(activity: 'initialize', name: 'event__ready')
             .add_script(contentType: 'application/x-formcalc')
             .text = script

        subform = form1.add_subform

        button = subform.add_field(name: 'Button1')
        button.add_ui.add_button(highlight: 'inverted')
        btncaption = button.add_caption
        btncaption.add_value.add_text.text = "Send!"
        btncaption.add_para(vAlign: 'middle', hAlign: 'center')
        button.add_bind(match: 'none')
        button.add_event(activity: 'click', name: 'event__click')
              .add_script(contentType: 'application/x-formcalc')
              .text = script

        txtfield = subform.add_field(name: 'TextField1')
        txtfield.add_ui.add_textEdit.add_border.add_edge(stroke: 'lowered')

        template
    end

    def create_datasets_packet
        datasets = XDP::Packet::Datasets.new
        data = datasets.add_element(XDP::Packet::Datasets::Data.new)

        data.add_element(XFA::Element.new('form1'))
            .add_element(XFA::Element.new('TextField1'))
            .text = '$host.messageBox("Hello from FormCalc!")'

        datasets
    end
end

pdf = PDF.new.append_page(page = Page.new)

contents = ContentStream.new.setFilter(:FlateDecode)

contents.write "Write your FormCalc below and run it",
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

ml = Template::MultiLineEdit.new('TextField1[0]', x: 50, y: 280, width: 500, height: 400)
button = Template::Button.new('Send!', id: 'Button1[0]', x: 490, y: 240, width: 60, height: 30)

page.add_annotation(ml, button)

form1 = Field::Subform.new(T: "form1[0]")
form1.add_fields(subform = Field::Subform.new(T: "#subform[0]"))
subform.add_fields(ml, button)

xdp = SampleXDP.new('Eval(Ref(form1[0].#subform[0].TextField1[0]))').to_s
pdf.create_xfa_form(xdp, form1)

pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
