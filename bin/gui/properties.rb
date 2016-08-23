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

                file_frame = create_file_frame(parent)
                pdf_frame = create_document_frame(pdf)

                vbox.add(file_frame)
                vbox.add(pdf_frame)

                signal_connect('response') { destroy }

                show_all
            end

            private

            def create_file_frame(parent)
                file_frame = Frame.new(" File properties ")
                stat = File.stat(parent.filename)

                labels =
                [
                    [ "Filename:", parent.filename ],
                    [ "File size:", "#{File.size(parent.filename)} bytes" ],
                    [ "MD5:", Digest::MD5.file(parent.filename).hexdigest ],
                    [ "Read-only:", "#{not stat.writable?}" ],
                    [ "Creation date:", stat.ctime.to_s ],
                    [ "Last modified:", stat.mtime.to_s ]
                ]

                create_table(file_frame, labels)
            end

            def create_document_frame(pdf)
                pdf_frame = Frame.new(" PDF properties ")

                pdf_version = pdf.header.to_f
                if pdf_version >= 1.0 and pdf_version <= 1.7
                    acrobat_version = @@acrobat_versions[pdf_version]
                else
                    acrobat_version = "unknown version"
                end

                labels =
                [
                    [ "Version:",                    "#{pdf_version} (Acrobat #{acrobat_version})" ],
                    [ "Number of revisions:",        "#{pdf.revisions.size}" ],
                    [ "Number of indirect objects:", "#{pdf.indirect_objects.size}" ],
                    [ "Number of pages:",            "#{pdf.pages.count}" ],
                    [ "Linearized:",           boolean_text(pdf.linearized?) ],
                    [ "Encrypted:",            boolean_text(pdf.encrypted?) ],
                    [ "Signed:",               boolean_text(pdf.signed?) ],
                    [ "Has usage rights:",     boolean_text(pdf.usage_rights?) ],
                    [ "Form:",                 boolean_text(pdf.form?) ],
                    [ "XFA form:",             boolean_text(pdf.xfa_form?) ],
                    [ "Document information:", boolean_text(pdf.document_info?) ],
                    [ "Metadata:",             boolean_text(pdf.metadata?) ]
                ]

                create_table(pdf_frame, labels)
            end

            def create_table(frame, labels)
                table = Table.new(labels.size + 1, 3)

                labels.each_with_index do |label, row|
                    table.attach(Label.new(label[0]).set_alignment(1,0), 0, 1, row, row + 1, Gtk::FILL,  Gtk::SHRINK, 4, 4)
                    table.attach(Label.new(label[1]).set_alignment(0,0), 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                end

                frame.border_width = 5
                frame.shadow_type = Gtk::SHADOW_IN
                frame.add(table)
            end

            def boolean_text(value)
                value ? 'yes' : 'no'
            end
        end
    end

end
