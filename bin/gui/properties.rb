=begin

    This file is part of PDF Walker, a graphical PDF file browser
    Copyright (C) 2016	Guillaume Delugré.

    PDF Walker is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    PDF Walker is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with PDF Walker.  If not, see <http://www.gnu.org/licenses/>.

=end

require 'digest/md5'

module PDFWalker

    class Walker < Window

        def display_file_properties
            Properties.new(self, @opened) if @opened
        end

        class Properties < Dialog

            @@acrobat_versions =
            {
                1.0 => "1.x",
                1.1 => "2.x",
                1.2 => "3.x",
                1.3 => "4.x",
                1.4 => "5.x",
                1.5 => "6.x",
                1.6 => "7.x",
                1.7 => "8.x / 9.x / 10.x"
            }

            def initialize(parent, pdf)
                super("Document properties", parent, Dialog::MODAL, [Stock::CLOSE, Dialog::RESPONSE_NONE])

                docframe = Frame.new(" File properties ")
                stat = File.stat(parent.filename)

                creation_date = stat.ctime.to_s.encode("utf-8", :invalid => :replace, :undef => :replace)
                last_modified = stat.mtime.to_s.encode("utf-8", :invalid => :replace, :undef => :replace)
                md5sum = Digest::MD5.hexdigest(File.binread(parent.filename))

                labels =
                [
                    [ "Filename:", parent.filename ],
                    [ "File size:", "#{File.size(parent.filename)} bytes" ],
                    [ "MD5:", md5sum ],
                    [ "Read-only:", "#{not stat.writable?}" ],
                    [ "Creation date:", creation_date ],
                    [ "Last modified:", last_modified ]
                ]

                doctable = Table.new(labels.size + 1, 3)

                row = 0
                labels.each do |name, value|
                    doctable.attach(Label.new(name).set_alignment(1,0), 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    doctable.attach(Label.new(value).set_alignment(0,0), 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                docframe.border_width = 5
                docframe.shadow_type = Gtk::SHADOW_IN
                docframe.add(doctable)

                pdfframe = Frame.new(" PDF properties ")

                pdf_version = pdf.header.to_f
                if pdf_version >= 1.0 and pdf_version <= 1.7
                    acrobat_version = @@acrobat_versions[pdf_version]
                else
                    acrobat_version = "unknown version"
                end

                labels =
                [
                    [ "Version:", "#{pdf_version} (Acrobat #{acrobat_version})" ],
                    [ "Number of revisions:", "#{pdf.revisions.size}" ],
                    [ "Number of indirect objects:", "#{pdf.indirect_objects.size}" ],
                    [ "Number of pages:", "#{pdf.pages.count}" ],
                    [ "Linearized:", pdf.linearized? ? 'yes' : 'no' ],
                    [ "Encrypted:", pdf.encrypted? ? 'yes' : 'no' ],
                    [ "Signed:", pdf.signed? ? 'yes' : 'no' ],
                    [ "Has usage rights:", pdf.usage_rights? ? 'yes' : 'no' ],
                    [ "Form:", pdf.form? ? 'yes' : 'no' ],
                    [ "XFA form:", pdf.xfa_form? ? 'yes' : 'no' ],
                    [ "Document information:", pdf.document_info? ? 'yes' : 'no' ],
                    [ "Metadata:", pdf.metadata? ? 'yes' : 'no' ]
                ]

                pdftable = Table.new(labels.size + 1, 3)

                row = 0
                labels.each do |name, value|
                    pdftable.attach(Label.new(name).set_alignment(1,0), 0, 1, row, row + 1, Gtk::FILL,  Gtk::SHRINK, 4, 4)
                    pdftable.attach(Label.new(value).set_alignment(0,0), 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                pdfframe.border_width = 5
                pdfframe.shadow_type = Gtk::SHADOW_IN
                pdfframe.add(pdftable)

                vbox.add(docframe)
                vbox.add(pdfframe)

                signal_connect('response') { destroy }

                show_all
            end
        end
    end

end
