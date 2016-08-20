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
                @file_menu_close, @file_menu_saveas, @file_menu_serialize, @file_menu_refresh,
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
                if @help_menu_profile.active?
                    require 'ruby-prof'
                    RubyProf.start
                end

                target = parse_file(filename)

                if @help_menu_profile.active?
                    result = RubyProf.stop
                    multiprinter = RubyProf::MultiPrinter.new(result)

                    Dir.mkdir(@config.profile_output_dir) unless Dir.exist?(@config.profile_output_dir) 

                    multiprinter.print(path: @config.profile_output_dir, profile: File.basename(filename))
                end

                if target
                    close if @opened
                    @opened = target
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

                    if @opened.is_a?(Origami::PDF)

                        # Enable save and document menu.
                        [
                            @file_menu_saveas, @file_menu_serialize,
                            @document_menu_search,
                            @document_menu_gotocatalog, @document_menu_gotopage, @document_menu_gotorev, @document_menu_gotoobj,
                            @document_menu_properties, @document_menu_sign, @document_menu_ur
                        ].each do |menu|
                            menu.sensitive = true
                        end

                        @document_menu_gotodocinfo.sensitive = true if @opened.document_info?
                        @document_menu_gotometadata.sensitive = true if @opened.metadata?
                        @document_menu_gotofield.sensitive = true if @opened.form?

                        page_menu = Menu.new
                        @document_menu_gotopage.remove_submenu
                        @opened.each_page.with_index(1) do |page, index|
                            page_menu.append(item = MenuItem.new(index.to_s).show)
                            item.signal_connect("activate") do @treeview.goto(page) end
                        end
                        @document_menu_gotopage.set_submenu(page_menu)

                        field_menu = Menu.new
                        @document_menu_gotofield.remove_submenu
                        @opened.each_field do |field|
                            field_name = field.T || "<unnamed field>"
                            field_menu.append(item = MenuItem.new(field_name).show)
                            item.signal_connect("activate") do @treeview.goto(field) end
                        end
                        @document_menu_gotofield.set_submenu(field_menu)

                        rev_menu = Menu.new
                        @document_menu_gotorev.remove_submenu
                        rev_index = 1
                        @opened.revisions.each do |rev|
                            rev_menu.append(item = MenuItem.new(rev_index.to_s).show)
                            item.signal_connect("activate") do @treeview.goto(rev) end
                            rev_index = rev_index + 1
                        end
                        @document_menu_gotorev.set_submenu(rev_menu)

                        goto_catalog
                    end
                end

            rescue
                error("Error while parsing file.\n#{$!} (#{$!.class})\n" + $!.backtrace.join("\n"))
            end

            close_progressbar
            self.activate_focus
        end

        def deserialize
            dialog = Gtk::FileChooserDialog.new("Open dump file",
                        self,
                        FileChooser::ACTION_OPEN,
                        nil,
                        [Stock::CANCEL, Dialog::RESPONSE_CANCEL],
                        [Stock::OPEN, Dialog::RESPONSE_ACCEPT]
            )

            dialog.current_folder = File.join(Dir.pwd, "dumps")
            dialog.filter = FileFilter.new.add_pattern("*.gz")

            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                close if @opened
                filename = dialog.filename

                begin
                    @opened = Origami::PDF.deserialize(filename)
                    self.reload

                    [
                        @file_menu_close, @file_menu_saveas, @file_menu_serialize, @file_menu_refresh,
                        @document_menu_search,
                        @document_menu_gotocatalog, @document_menu_gotopage, @document_menu_gotorev, @document_menu_gotoobj,
                        @document_menu_properties, @document_menu_sign, @document_menu_ur
                    ].each do |menu|
                        menu.sensitive = true
                    end

                    @document_menu_gotodocinfo.sensitive = true if @opened.document_info?
                    @document_menu_gotometadata.sensitive = true if @opened.metadata?
                    @document_menu_gotofield.sensitive = true if @opened.form?

                    @explorer_history.clear

                    @statusbar.push(@main_context, "Viewing dump of #{filename}")
                rescue
                    error("This file cannot be loaded.\n#{$!} (#{$!.class})")
                end
            end

            dialog.destroy
        end

        def serialize
            dialog = Gtk::FileChooserDialog.new("Save dump file",
                        self,
                        Gtk::FileChooser::ACTION_SAVE,
                        nil,
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT]
            )

            dialog.do_overwrite_confirmation = true
            dialog.current_folder = File.join(Dir.pwd, "dumps")
            dialog.current_name = "#{File.basename(@filename)}.dmp.gz"
            dialog.filter = FileFilter.new.add_pattern("*.gz")

            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                begin
                    @opened.serialize(dialog.filename)
                rescue
                    error("Error: #{$!.message}")
                end
            end

            dialog.destroy
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

        def save_dot
            dialog = Gtk::FileChooserDialog.new("Save dot file",
                        self,
                        Gtk::FileChooser::ACTION_SAVE,
                        nil,
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT]
            )

            dialog.filter = FileFilter.new.add_pattern("*.dot")

            folder = File.dirname(@filename)
            dialog.set_current_folder(folder)

            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                begin
                    @opened.export_to_graph(dialog.filename)
                rescue
                    error("Error: #{$!.message}")
                end
            end

            dialog.destroy
        end

        def save_graphml
            dialog = Gtk::FileChooserDialog.new("Save GraphML file",
                        self,
                        Gtk::FileChooser::ACTION_SAVE,
                        nil,
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT]
            )

            dialog.filter = FileFilter.new.add_pattern("*.graphml")

            folder = File.dirname(@filename)
            dialog.set_current_folder(folder)

            if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                begin
                    @opened.export_to_graphml(dialog.filename)
                rescue
                    error("Error: #{$!.message}")
                end
            end

            dialog.destroy
        end

        private

        def parse_file(path)
            update_bar = lambda do |_obj|
                @progressbar.pulse if @progressbar
                Gtk.main_iteration while Gtk.events_pending?
            end

            prompt_passwd = lambda do
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
                    if response == Gtk::Dialog::RESPONSE_OK
                        passwd = entry.text
                    end
                end

                dialog.destroy
                return passwd
            end

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
                callback: update_bar,
                prompt_password: prompt_passwd,
                force: force_mode
            )
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
