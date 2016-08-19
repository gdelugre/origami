Origami
=====
[![Gem Version](https://badge.fury.io/rb/origami.svg)](http://rubygems.org/gems/origami)

Overview
--------

Origami is a framework written in pure Ruby to manipulate PDF files.

It offers the possibility to parse the PDF contents, modify and save the PDF
structure, as well as creating new documents.

Origami supports some advanced features of the PDF specification:

* Compression filters with predictor functions
* Encryption using RC4 or AES, including the undocumented Revision 6 derivation algorithm
* Digital signatures and Usage Rights
* File attachments
* AcroForm and XFA forms
* Object streams

Origami is able to parse PDF, FDF and PPKLite (Adobe certificate store) files.

Requirements
------------

As of version 2, the minimal version required to run Origami is Ruby 2.1.

Some optional features require additional gems:

* [Gtk2][ruby-gtk2] for running the GUI interface
* [therubyracer][the-ruby-racer] for JavaScript emulation of PDF scripts

[ruby-gtk2]: https://rubygems.org/gems/gtk2
[the-ruby-racer]: https://rubygems.org/gems/therubyracer

Quick start
-----------

First install Origami using the latest gem available:

    $ gem install origami

Then import Origami with:

```ruby
require 'origami'
```

To process a PDF document, you can use the ``PDF.read`` method:

```ruby
pdf = PDF.read "something.pdf"

puts "This document has #{pdf.pages.size} page(s)"
```

The default behavior is to parse the entire contents of the document at once. This can be changed by passing the ``lazy`` flag to parse objects on demand.

```ruby
pdf = PDF.read "something.pdf", lazy: true

pdf.each_page do |page|
    page.each_font do |name, font|
        # ... only parse the necessary bits
    end
end
```

You can also create documents directly by instanciating a new PDF object:

```ruby
pdf = PDF.new

pdf.append_page
pdf.pages.first.write "Hello", size: 30

pdf.save("example.pdf")

# Another way of doing it
PDF.write("example.pdf") do |pdf|
    pdf.append_page do |page|
        page.write "Hello", size: 30
    end
end
```

Take a look at the [examples](examples) and [bin](bin) directories for some examples of advanced usage.

Tools
-----

Origami comes with a set of tools to manipulate PDF documents from the command line.

* [pdfcop](bin/pdfcop): Runs some heuristic checks to detect dangerous contents.
* [pdfdecompress](bin/pdfdecompress): Strips compression filters out of a document.
* [pdfdecrypt](bin/pdfdecrypt): Removes encrypted contents from a document.
* [pdfencrypt](bin/pdfencrypt): Encrypts a PDF document.
* [pdfexplode](bin/pdfexplode): Explodes a document into several documents, each of them having one deleted resource. Useful for reduction of crash cases after a fuzzing session.
* [pdfextract](bin/pdfextract): Extracts binary resources of a document (images, scripts, fonts, etc.).
* [pdfmetadata](bin/pdfmetadata): Displays the metadata contained in a document.
* [pdf2ruby](bin/pdf2ruby): Converts a PDF into an Origami script rebuilding an equivalent document (experimental).
* [pdfsh](bin/pdfsh): An IRB shell running inside the Origami namespace.
* [pdfwalker](bin/pdfwalker): A graphical interface to dig into the contents of a PDF document.


License
-------

Origami is distributed under the [LGPL](COPYING.LESSER) license, except for the graphical interface which is distributed under the [GPL](bin/gui/COPYING) license.

Copyright © 2016 Guillaume Delugré.
