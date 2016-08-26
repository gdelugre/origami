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

module PDFWalker

    module PopupMenu

        @@menus = Hash.new([])
        @@menus['PDF'] =
        [
            {
                Name: Stock::SAVE_AS,
                Sensitive: true,
                Callback: lambda { |_widget, viewer, _path|
                    viewer.parent.save
                }
            },
            {
                Name: :"---"
            },
            {
                Name: Stock::PROPERTIES,
                Sensitive: true,
                Callback: lambda { |_widget, viewer, _path|
                    viewer.parent.display_file_properties
                }
            },
            {
                Name: :"---"
            },
            {
                Name: Stock::CLOSE,
                Sensitive: true,
                Callback: lambda { |_widget, viewer, _path|
                    viewer.parent.close
                }
            }
        ]

        @@menus['Reference'] =
        [
            {
                Name: Stock::JUMP_TO,
                Sensitive: true,
                Callback: lambda { |_widget, viewer, path|
                    viewer.row_activated(path, viewer.get_column(viewer.class::TEXTCOL))
                }
            }
        ]

        @@menus['Revision'] =
        [
            {
                Name: "Save to this revision",
                Sensitive: true,
                Callback: lambda { |_widget, viewer, path|
                    revstr = viewer.model.get_value(viewer.model.get_iter(path), viewer.class::TEXTCOL)
                    revstr.slice!(0, "Revision ".size)

                    revnum = revstr.to_i

                    dialog = Gtk::FileChooserDialog.new("Save PDF File",
                        viewer.parent,
                        Gtk::FileChooser::ACTION_SAVE,
                        nil,
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                        [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT]
                    )

                    dialog.filter = FileFilter.new.add_pattern("*.pdf")

                    if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
                        viewer.parent.opened.save_upto(revnum, dialog.filename)
                    end

                    dialog.destroy
                }
            }
        ]

        @@menus['Stream'] =
        [
            {
                Name: "Dump encoded stream",
                Sensitive: true,
                Callback: lambda { |_widget, viewer, path|
                    stream = viewer.object_by_path(path)

                    viewer.parent.save_data("Save encoded stream to file", stream.encoded_data)
                }
            },
            {
                Name: "Dump decoded stream",
                Sensitive: true,
                Callback: lambda { |_widget, viewer, path|
                    stream = viewer.object_by_path(path)

                    viewer.parent.save_data("Save decoded stream to file", stream.data)
                }
            }
        ]

        @@menus['String'] =
        [
            {
                Name: "Dump string",
                Sensitive: true,
                Callback: lambda { |_widget, viewer, path|
                    string = viewer.object_by_path(path)

                    viewer.parent.save_data("Save string to file", string.value)
                }
            }
        ]

        @@menus['Image'] = @@menus['Stream'] +
        [
            {
                Name: :"---"
            },
            {
                Name: "View image",
                Sensitive: true,
                Callback: lambda { |_widget, viewer, path|
                    stm = viewer.object_by_path(path)
                    w,h = stm.Width, stm.Height

                    if stm.ColorSpace.nil?
                        colors = 1
                    else
                        colors =
                            case stm.ColorSpace.value
                            when :DeviceGray then 1
                            when :DeviceRGB then 3
                            when :DeviceCMYK then 4
                            else
                                1
                            end
                    end

                    bpc = stm.BitsPerComponent || 8
                    bpr = (w * colors * bpc + 7) >> 3
                    data = stm.data

                    begin
                        imgview = ImgViewer.new
                        if stm.Filter == :DCTDecode or (stm.Filter.is_a?(Array) and stm.Filter[0] == :DCTDecode)
                            imgview.show_compressed_img data
                        else
                            imgview.show_raw_img data, w, h, bpc, bpr
                        end
                    rescue
                        viewer.parent.error("#{$!.class}: #{$!.message}")
                    end
                }
            }
        ]

        def popup_menu(obj, event, path)
            menu = Menu.new

            type = popup_menu_key(obj)

            # Create menu title.
            title = obj.is_a?(Origami::Object) ? "Object : " : ""
            title << type.to_s
            menu.append(MenuItem.new(title).set_sensitive(false).modify_text(Gtk::STATE_INSENSITIVE, Gdk::Color.new(255,0,255)))

            # Object information.
            create_object_menu(menu, obj) if obj.is_a?(Origami::Object)

            # Type-specific menu.
            create_type_menu(menu, type, path)

            menu.show_all
            menu.popup(nil, nil, event.button, event.time)
        end

        private

        def create_object_menu(menu, object)
            if object.indirect?
                menu.append(MenuItem.new("Number : #{object.no}; Generation : #{object.generation}").set_sensitive(false))
                menu.append(MenuItem.new("File offset : #{object.file_offset}").set_sensitive(false))

                getxrefs = MenuItem.new("Search references to this object").set_sensitive(true)
                getxrefs.signal_connect("activate") do
                    self.parent.show_xrefs(object)
                end
                menu.append(getxrefs)

            elsif not object.parent.nil?
                gotoparent = MenuItem.new("Goto Parent Object").set_sensitive(true)
                gotoparent.signal_connect("activate") do
                    self.goto(object.parent)
                end
                menu.append(gotoparent)
            end
        end

        def create_type_menu(menu, type, path)
            items = @@menus[type]
            menu.append(SeparatorMenuItem.new) if not items.empty?

            items.each do |item|
                if item[:Name] == :"---"
                    entry = SeparatorMenuItem.new
                else
                    if item[:Name].is_a?(String)
                        entry = MenuItem.new(item[:Name])
                    else
                        entry = ImageMenuItem.new(item[:Name])
                    end

                    entry.set_sensitive(item[:Sensitive])
                    entry.signal_connect("activate", self, path, &item[:Callback])
                end

                menu.append(entry)
            end
        end

        def popup_menu_key(object)
            if object.is_a?(Origami::Object)
                popup_menu_object_key(object)
            else
                popup_menu_struct_key(object)
            end
        end

        def popup_menu_object_key(object)
            if object.is_a?(Origami::Graphics::ImageXObject)
                'Image'
            else
                object.native_type.to_s.split("::").last
            end
        end

        def popup_menu_struct_key(struct)
            case struct
            when ::Array
                'Body'
            when Origami::XRef, Origami::XRefToCompressedObject
                'XRef'
            else
                struct.class.name.split('::').last
            end
        end
    end

    class Walker < Window

        private

        def create_menus
            AccelMap.add_entry("<PDF Walker>/File/Open", Gdk::Keyval::GDK_O, Gdk::Window::CONTROL_MASK)
            AccelMap.add_entry("<PDF Walker>/File/Refresh", Gdk::Keyval::GDK_R, Gdk::Window::CONTROL_MASK)
            AccelMap.add_entry("<PDF Walker>/File/Close", Gdk::Keyval::GDK_W, Gdk::Window::CONTROL_MASK)
            AccelMap.add_entry("<PDF Walker>/File/Save", Gdk::Keyval::GDK_S, Gdk::Window::CONTROL_MASK)
            AccelMap.add_entry("<PDF Walker>/File/Quit", Gdk::Keyval::GDK_Q, Gdk::Window::CONTROL_MASK)
            AccelMap.add_entry("<PDF Walker>/Document/Search", Gdk::Keyval::GDK_F, Gdk::Window::CONTROL_MASK)

            @menu = MenuBar.new

            create_file_menu 
            create_document_menu
            create_help_menu
        end

        def create_file_menu
            file_ag = Gtk::AccelGroup.new
            @file_menu = Menu.new.set_accel_group(file_ag).set_accel_path("<PDF Walker>/File")
            add_accel_group(file_ag)

            entries = [
                @file_menu_open = ImageMenuItem.new(Stock::OPEN).set_accel_path("<PDF Walker>/File/Open"),
                @file_menu_recent = MenuItem.new("Last opened"),
                @file_menu_refresh = ImageMenuItem.new(Stock::REFRESH).set_sensitive(false).set_accel_path("<PDF Walker>/File/Refresh"),
                @file_menu_close = ImageMenuItem.new(Stock::CLOSE).set_sensitive(false).set_accel_path("<PDF Walker>/File/Close"),
                @file_menu_saveas = ImageMenuItem.new(Stock::SAVE_AS).set_sensitive(false).set_accel_path("<PDF Walker>/File/Save"),
                @file_menu_exit = ImageMenuItem.new(Stock::QUIT).set_accel_path("<PDF Walker>/File/Quit"),
            ]

            @file_menu_open.signal_connect('activate') { open }
            @file_menu_refresh.signal_connect('activate') { open(@filename) }
            @file_menu_close.signal_connect('activate') { close }
            @file_menu_saveas.signal_connect('activate') { save }
            @file_menu_exit.signal_connect('activate') { self.destroy }

            update_recent_menu

            entries.each do |entry|
                @file_menu.append(entry)
            end

            @menu.append(MenuItem.new('_File').set_submenu(@file_menu))
        end

        def create_document_menu
            doc_ag = Gtk::AccelGroup.new
            @document_menu = Menu.new.set_accel_group(doc_ag)
            add_accel_group(doc_ag)

            entries = [
                @document_menu_search = ImageMenuItem.new(Stock::FIND).set_sensitive(false).set_accel_path("<PDF Walker>/Document/Search"),
                MenuItem.new,
                @document_menu_gotocatalog = MenuItem.new("Jump to Catalog").set_sensitive(false),
                @document_menu_gotodocinfo = MenuItem.new("Jump to Document Info").set_sensitive(false),
                @document_menu_gotometadata = MenuItem.new("Jump to Metadata").set_sensitive(false),
                @document_menu_gotorev = MenuItem.new("Jump to Revision...").set_sensitive(false),
                @document_menu_gotopage = MenuItem.new("Jump to Page...").set_sensitive(false),
                @document_menu_gotofield = MenuItem.new("Jump to Field...").set_sensitive(false),
                @document_menu_gotoobj = MenuItem.new("Jump to Object...").set_sensitive(false),
                MenuItem.new,
                @document_menu_sign = MenuItem.new("Sign the document").set_sensitive(false),
                @document_menu_ur = MenuItem.new("Enable Usage Rights").set_sensitive(false),
                @document_menu_properties = ImageMenuItem.new(Stock::PROPERTIES).set_sensitive(false),
            ]

            @document_menu_search.signal_connect('activate') { search }
            @document_menu_gotocatalog.signal_connect('activate') { goto_catalog }
            @document_menu_gotodocinfo.signal_connect('activate') { goto_docinfo }
            @document_menu_gotometadata.signal_connect('activate') { goto_metadata }
            @document_menu_gotoobj.signal_connect('activate') { goto_object }
            @document_menu_properties.signal_connect('activate') { display_file_properties }
            @document_menu_sign.signal_connect('activate') { display_signing_wizard }
            @document_menu_ur.signal_connect('activate') { display_usage_rights_wizard }

            entries.each do |entry|
                @document_menu.append(entry)
            end

            @menu.append(MenuItem.new('_Document').set_submenu(@document_menu))
        end

        def create_help_menu
            @help_menu = Menu.new

            @help_menu_profile = CheckMenuItem.new("Profiling (Debug purposes only)").set_active(@config.profile?)
            @help_menu_about = ImageMenuItem.new(Stock::ABOUT)

            @help_menu_profile.signal_connect('toggled') do @config.set_profiling(@help_menu_profile.active?) end
            @help_menu_about.signal_connect('activate') { about }

            @help_menu.append(@help_menu_profile)
            @help_menu.append(@help_menu_about)

            @menu.append(MenuItem.new('_Help').set_submenu(@help_menu))
        end

        def update_recent_menu
            @recent_menu = Menu.new
            @config.recent_files.each { |file|
                menu = MenuItem.new(file)
                menu.signal_connect('activate') do open(file) end

                @recent_menu.append(menu)
            }

            @file_menu_recent.set_submenu(@recent_menu)
            @file_menu_recent.show_all
        end
    end

end
