2.1.0
-----
* Moved pdfwalker to a separate gem

2.0.0
-----
* Code reindented to 4 spaces.
* Code base refactored for Ruby 2.x (requires at least 2.1).
* Support for Crypt filters.
* The parser now supports a lazy mode.
* Fixed all Ruby warnings.
* Better type propagation.
* Use namespace refinements to protect the standard namespace.
* PDF#each_* methods can return Enumerators.
* Use the colorize gem for console output.
* Faster loading of objects in pdfwalker.
* Better handling of cross-references in pdfwalker.
* Many bug fixes.

1.2.0 (2011-09-29)
-----
* Support for JavaScript emulation based on V8 (requires therubyracer gem).

1.1.0 (2011-09-14)
-----
* Support for standard security handler revision 6.

1.0.2 (2011-05-25)
-----
* Added a Rakefile to run unit tests, build rdoc and build gem.
* Added a Ruby shell for Origami.
* Added a bin folder, with some useful command-line tools.
* Can now be installed as a RubyGem.
* AESV3 support (AES256 encryption/decryption).
* Encryption/decryption can be achieved with or without openssl.
* Changed PDF#encrypt prototype.
* Support for G3 unidimensional encoding/decoding of CCITTFax filter.
* Support for TIFF stream predictor functions.
* Name trees lookup methods.
* Renamed PDF#saveas to PDF#save.
* Lot of bug fixes.

beta3 (2010-08-26)
-----
* Faster decryption process.
* Properly parse objects with no endobj token.
* Image viewer in pdfwalker.

beta2 (2010-04-01)
-----
* Support for Flash/RichMedia integration.
* XFA forms.
* Search feature for pdfwalker.
* Fixed various bugs.

beta1 (2009-09-15)
-----
* Basic support for graphics drawing as lines, colors, shading, shapes...
* Support for numerical functions.
* Support for date strings.
* Added PDF#insert_page(index, page) method.
* Added a forms widgets template.
* Ability to delinearize documents.
* Fixed various bugs.

beta0 (2009-07-06)
-----
* Support for XRef streams. 
* Support for Object streams creation. 
* Support for PNG stream predictor functions.
