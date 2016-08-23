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

require 'origami'

module PDFWalker

    class Walker < Window
        attr_reader :opened
        attr_reader :explore_history

        def close
            @opened = nil
            @filename = ''
            @explorer_history.clear

            @treeview.clear
            @objectview.clear
            @hexview.clear

            # disable all menus.
            [
                @file_menu_close, @file_menu_saveas, @file_menu_refresh,
                @document_menu_search,
                @document_menu_gotocatalog, @document_menu_gotodocinfo, @document_menu_gotometadata,
                @document_menu_gotopage, @document_menu_gotofield, @document_menu_gotorev, @document_menu_gotoobj,
                @document_menu_properties, @document_menu_sign, @document_menu_ur
            ].each do |menu|
                menu.sensitive = false
            end

            @statusbar.pop(@main_context)

            GC.start
        end

        def open(filename = nil)
            dialog = Gtk::FileChooserDialog.new("Open PDF File",
                        self,
                        FileChooser::ACTION_OPEN,
                        nil,
                        [Stock::CANCEL, Dialog::RESPONSE_CANCEL],
                        [Stock::OPEN, Dialog::RESPONSE_ACCEPT])

            last_file = @config.recent_files.first
            unless last_file.nil?
                last_folder = File.dirname(last_file)
                dialog.set_current_folder(last_folder) if File.directory?(last_folder)
            end

            dialog.filter = FileFilter.new.add_pattern("*.acrodata").add_pattern("*.pdf").add_pattern("*.fdf")

            if filename.nil? and dialog.run != Gtk::Dialog::RESPONSE_ACCEPT
                dialog.destroy
                return
            end

            create_progressbar

            filename ||= dialog.filename
            dialog.destroy

            begin
                document = start_profiling do
                    parse_file(filename)
                end

                set_active_document(filename, document)

            rescue
                error("Error while parsing file.\n#{$!} (#{$!.class})\n" + $!.backtrace.join("\n"))
            ensure
                close_progressbar
                self.activate_focus
            end
        end

        def save_data(caption, data, filename = "")
            dialog = Gtk::FileChooserDialog.new(caption,
                        self,
                        Gtk::FileChooser::ACTION_SAVE,
                        nil,
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT]
            )

            dialog.do_overwrite_confirmation = true
            dialog.current_name = File.basename(filename)
            dialog.filter = FileFilter.new.add_pattern("*.*")

            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                begin
                    File.binwrite(dialog.filename, data)
                rescue
                    error("Error: #{$!.message}")
                end
            end

            dialog.destroy
        end

        def save
            dialog = Gtk::FileChooserDialog.new("Save PDF file",
                        self,
                        Gtk::FileChooser::ACTION_SAVE,
                        nil,
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT]
            )

            dialog.filter = FileFilter.new.add_pattern("*.acrodata").add_pattern("*.pdf").add_pattern("*.fdf")

            folder = File.dirname(@filename)
            dialog.set_current_folder(folder)

            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                begin
                    @opened.save(dialog.filename)
                rescue
                    error("#{$!.class}: #{$!.message}\n#{$!.backtrace.join($/)}")
                end
            end

            dialog.destroy
        end

        private

        def set_active_document(filename, document)
            close if @opened
            @opened = document
            @filename = filename

            @config.last_opened_file(filename)
            @config.save
            update_recent_menu

            @last_search_result = []
            @last_search =
            {
                :expr => "",
                :regexp => false,
                :type => :body
            }

            self.reload

            # Enable basic file menus.
            [
                @file_menu_close, @file_menu_refresh,
            ].each do |menu|
                menu.sensitive = true
            end

            @explorer_history.clear

            @statusbar.push(@main_context, "Viewing #{filename}")

            setup_pdf_interface if @opened.is_a?(Origami::PDF)
        end

        def setup_pdf_interface
            # Enable save and document menu.
            [
                @file_menu_saveas,
                @document_menu_search,
                @document_menu_gotocatalog, @document_menu_gotopage, @document_menu_gotorev, @document_menu_gotoobj,
                @document_menu_properties, @document_menu_sign, @document_menu_ur
            ].each do |menu|
                menu.sensitive = true
            end

            @document_menu_gotodocinfo.sensitive = true if @opened.document_info?
            @document_menu_gotometadata.sensitive = true if @opened.metadata?
            @document_menu_gotofield.sensitive = true if @opened.form?

            setup_page_menu
            setup_field_menu
            setup_revision_menu

            goto_catalog
        end

        def setup_page_menu
            page_menu = Menu.new
            @document_menu_gotopage.remove_submenu
            @opened.each_page.with_index(1) do |page, index|
                page_menu.append(item = MenuItem.new(index.to_s).show)
                item.signal_connect("activate") { @treeview.goto(page) }
            end
            @document_menu_gotopage.set_submenu(page_menu)
        end

        def setup_field_menu
            field_menu = Menu.new
            @document_menu_gotofield.remove_submenu
            @opened.each_field do |field|
                field_name = field.T || "<unnamed field>"
                field_menu.append(item = MenuItem.new(field_name).show)
                item.signal_connect("activate") { @treeview.goto(field) }
            end
            @document_menu_gotofield.set_submenu(field_menu)
        end

        def setup_revision_menu
            rev_menu = Menu.new
            @document_menu_gotorev.remove_submenu
            @opened.revisions.each.with_index(1) do |rev, index|
                rev_menu.append(item = MenuItem.new(index.to_s).show)
                item.signal_connect("activate") { @treeview.goto(rev) }
            end
            @document_menu_gotorev.set_submenu(rev_menu)
        end

        def parse_file(path)
            #
            # Try to detect the file type of the document.
            # Fallback to PDF if none is found.
            #
            file_type = detect_file_type(path)
            if file_type.nil?
                file_type = Origami::PDF
                force_mode = true
            else
                force_mode = false
            end

            file_type.read(path,
                verbosity: Origami::Parser::VERBOSE_TRACE,
                ignore_errors: false,
                callback: method(:update_progressbar),
                prompt_password: method(:prompt_password),
                force: force_mode
            )
        end

        def update_progressbar(_obj)
            @progressbar.pulse if @progressbar
            Gtk.main_iteration while Gtk.events_pending?
        end

        def prompt_password
            passwd = ""

            dialog = Gtk::Dialog.new(
                        "This document is encrypted",
                        nil,
                        Gtk::Dialog::MODAL,
                        [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK ],
                        [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL ]
            )

            dialog.set_default_response(Gtk::Dialog::RESPONSE_OK)

            label = Gtk::Label.new("Please enter password:")
            entry = Gtk::Entry.new
            entry.signal_connect('activate') {
                dialog.response(Gtk::Dialog::RESPONSE_OK)
            }

            dialog.vbox.add(label)
            dialog.vbox.add(entry)
            dialog.show_all

            dialog.run do |response|
                passwd = entry.text if response == Gtk::Dialog::RESPONSE_OK
            end

            dialog.destroy
            passwd
        end

        def detect_file_type(path)
            supported_types = [ Origami::PDF, Origami::FDF, Origami::PPKLite ]

            File.open(path, 'rb') do |file|
                data = file.read(128)

                supported_types.each do |type|
                    return type if data.match(type::Header::MAGIC)
                end
            end

            nil
        end

        def create_progressbar
            @progresswin = Dialog.new("Parsing file...", self, Dialog::MODAL)
            @progresswin.vbox.add(@progressbar = ProgressBar.new.set_pulse_step(0.05))
            @progresswin.show_all
        end

        def close_progressbar
            @progresswin.close
        end
    end
end
