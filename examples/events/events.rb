#!/usr/bin/ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "../../lib")
    require 'origami'
end
include Origami

OUTPUT_FILE = "#{File.basename(__FILE__, ".rb")}.pdf"

pdf = PDF.new

page = Page.new

contents = ContentStream.new
contents.write "Pass your mouse over the square",
    x: 180, y: 750, size: 15

page.setContents( contents )

onpageopen = Action::JavaScript "app.alert('Page Opened');"
onpageclose = Action::JavaScript "app.alert('Page Closed');"
ondocumentopen = Action::JavaScript "app.alert('Document is opened');"
ondocumentclose = Action::JavaScript "app.alert('Document is closing');"
onmouseover = Action::JavaScript "app.alert('Mouse over');"
onmouseleft = Action::JavaScript "app.alert('Mouse left');"
onmousedown = Action::JavaScript "app.alert('Mouse down');"
onmouseup = Action::JavaScript "app.alert('Mouse up');"
onparentopen = Action::JavaScript "app.alert('Parent page has opened');"
onparentclose = Action::JavaScript "app.alert('Parent page has closed');"
onparentvisible = Action::JavaScript "app.alert('Parent page is visible');"
onparentinvisible = Action::JavaScript "app.alert('Parent page is no more visible');"
namedscript = Action::JavaScript "app.alert('Names directory script');"

pdf.onDocumentOpen(ondocumentopen)
pdf.onDocumentClose(ondocumentclose)
page.onOpen(onpageopen).onClose(onpageclose)

pdf.register(Names::JAVASCRIPT, "test", namedscript)

rect_coord = Rectangle[llx: 270, lly: 700, urx: 330, ury: 640]

# Just draw a yellow rectangle.
rect = Annotation::Square.new
rect.Rect = rect_coord
rect.IC = [ 255, 255, 0 ]

# Creates a new annotation which will catch mouse actions.
annot = Annotation::Screen.new
annot.Rect = rect_coord

# Bind the scripts to numerous triggers.
annot.onMouseOver(onmouseover)
annot.onMouseOut(onmouseleft)
annot.onMouseDown(onmousedown)
annot.onMouseUp(onmouseup)
annot.onPageOpen(onparentopen)
annot.onPageClose(onparentclose)
annot.onPageVisible(onparentvisible)
annot.onPageInvisible(onparentinvisible)

page.add_annotation(annot)
page.add_annotation(rect)

pdf.append_page(page)

# Save the resulting file.
pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
