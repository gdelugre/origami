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

contents = ContentStream.new.setFilter(:FlateDecode)
contents.write OUTPUT_FILE,
  :x => 200, :y => 750, :rendering => Text::Rendering::FILL, :size => 30

contents.write "The script first tries to run your browser using JavaScript.",
  :x => 100, :y => 670, :size => 15

# A JS script to execute at the opening of the document
jscript = <<JS
try {
    app.launchURL("#{URL}");
}
catch(e) {}

try {
    this.submitForm(
    {
        cURL: "#{URL}",
        bAnnotations: true,
        bGet: true,
        cSubmitAs: "XML"
    });
}
catch(e) {}
JS

pdf = PDF.new

pdf.append_page do |page|
    page.Contents = contents
end

# Create a new action based on the script, compressed with zlib
jsaction = Action::JavaScript Stream.new(jscript)#@ Filter: :FlateDecode)

# Add the script into the document names dictionary.
# Any scripts registered here will be executed at the document opening (with no OpenAction implied).
pdf.register(Names::JAVASCRIPT, "Update", jsaction)

# Save the resulting file
pdf.save(OUTPUT_FILE)

puts "PDF file saved as #{OUTPUT_FILE}."
