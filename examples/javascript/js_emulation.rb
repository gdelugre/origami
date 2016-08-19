#!/usr/bin/env ruby

begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, "/../../lib")
    require 'origami'
end
include Origami

#
# Emulating JavaScript inside a PDF object.
#

if defined?(PDF::JavaScript::Engine)

    # Creating a new file
    pdf = PDF.new

    # Embedding the file into the PDF.
    pdf.attach_file(DATA,
        name: "README.txt",
        filter: :ASCIIHexDecode
    )

    # Example of JS payload
    pdf.onDocumentOpen Action::JavaScript <<-JS
        if ( app.viewerVersion == 8 )
          eval("this.exportDataObject({cName:'README.txt', nLaunch:2});");
        this.closeDoc();
    JS

    # Tweaking the engine options
    pdf.js_engine.options[:log_method_calls] = true
    pdf.js_engine.options[:viewerVersion] = 10

    # Hooking eval()
    pdf.js_engine.hook 'eval' do |eval, expr|
        puts "Hook: eval(#{expr.inspect})"
        eval.call(expr) # calling the real eval method
    end

    # Example of inline JS evaluation
    pdf.eval_js 'console.println(util.stringFromStream(this.getDataObjectContents("README.txt")))'

    # Executes the string as a JS script
    pdf.Catalog.OpenAction[:JS].eval_js

else
    abort "JavaScript support not found. You need to install therubyracer gem."
end

__END__
** THIS IS THE EMBEDDED FILE **
