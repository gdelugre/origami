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

    class Walker < Window

        private

        def create_treeview
            @treeview = PDFTree.new(self).set_headers_visible(false)

            colcontent = Gtk::TreeViewColumn.new("Names",
                Gtk::CellRendererText.new.set_foreground_set(true).set_background_set(true),
                    text: PDFTree::TEXTCOL,
                    weight: PDFTree::WEIGHTCOL,
                    style: PDFTree::STYLECOL,
                    foreground: PDFTree::FGCOL,
                    background: PDFTree::BGCOL
            )

            @treeview.append_column(colcontent)
        end
    end

    class PDFTree < TreeView
        include Popable

        OBJCOL = 0
        TEXTCOL = 1
        WEIGHTCOL = 2
        STYLECOL = 3
        FGCOL = 4
        BGCOL = 5
        LOADCOL = 6

        @@appearance = Hash.new(Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_NORMAL)

        attr_reader :parent

        def initialize(parent)
            @parent = parent

            reset_appearance

            @treestore = TreeStore.new(Object::Object, String, Pango::FontDescription::Weight, Pango::FontDescription::Style, String, String, Fixnum)
            super(@treestore)

            signal_connect('cursor-changed') {
                iter = selection.selected
                if iter
                    obj = @treestore.get_value(iter, OBJCOL)

                    parent.hexview.load(obj)
                    parent.objectview.load(obj)
                end
            }

            signal_connect('row-activated') { |tree, path, column|
                if selection.selected
                    obj = @treestore.get_value(selection.selected, OBJCOL)

                    if row_expanded?(path)
                        collapse_row(path)
                    else
                        expand_row(path, false)
                    end

                    goto(obj) if obj.is_a?(Origami::Reference)
                end
            }

            signal_connect('row-expanded') { |tree, iter, path|
                obj = @treestore.get_value(iter, OBJCOL)

                if obj.is_a?(Origami::Stream) and iter.n_children == 1

                    # Processing with an XRef or Object Stream
                    if obj.is_a?(Origami::ObjectStream)
                        obj.each { |embeddedobj|
                            load_object(iter, embeddedobj)
                        }

                    elsif obj.is_a?(Origami::XRefStream)
                        obj.each { |xref|
                            load_xrefstm(iter, xref)
                        }
                    end
                end

                for i in 0...iter.n_children
                    subiter = iter.nth_child(i)
                    subobj = @treestore.get_value(subiter, OBJCOL)

                    load_sub_objects(subiter, subobj)
                end
            }

            add_events(Gdk::Event::BUTTON_PRESS_MASK)
            signal_connect('button_press_event') { |widget, event|
                if event.button == 3 && parent.opened
                    path = get_path(event.x,event.y).first
                    set_cursor(path, nil, false)

                    obj = @treestore.get_value(@treestore.get_iter(path), OBJCOL)
                    popup_menu(obj, event, path)
                end
            }
        end

        def clear
            @treestore.clear
        end

        def goto(obj, follow_references: true)
            if obj.is_a?(TreePath)
                set_cursor(obj, nil, false)
            else
                if obj.is_a?(Origami::Name) and obj.parent.is_a?(Origami::Dictionary) and obj.parent.has_key?(obj)
                    obj = obj.parent[obj]
                elsif obj.is_a?(Origami::Reference) and follow_references
                    obj =
                        begin
                            obj.solve
                        rescue Origami::InvalidReferenceError
                            @parent.error("Object not found : #{obj}")
                            return
                        end
                end

                _, path = object_to_tree_pos(obj)
                if path.nil?
                    @parent.error("Object not found : #{obj.type}")
                    return
                end

                expand_to_path(path) unless row_expanded?(path)
                @parent.explorer_history << cursor.first if cursor.first
                set_cursor(path, nil, false)
            end
        end

        def highlight(obj, color)
            if obj.is_a?(Origami::Name) and obj.parent.is_a?(Origami::Dictionary) and obj.parent.has_key?(obj)
                obj = obj.parent[obj]
            end

            iter, path = object_to_tree_pos(obj)
            if iter.nil? or path.nil?
                @parent.error("Object not found : #{obj.type}")
                return
            end

            @treestore.set_value(iter, BGCOL, color)
            expand_to_path(path) unless row_expanded?(path)
        end

        def load(pdf)
            return unless pdf

            self.clear

            begin
                #
                # Create root entry
                #
                root = @treestore.append(nil)
                @treestore.set_value(root, OBJCOL, pdf)

                set_node(root, :Filename, @parent.filename)

                #
                # Create header entry
                #
                header = @treestore.append(root)
                @treestore.set_value(header, OBJCOL, pdf.header)

                set_node(header, :Header,
                         "Header (version #{pdf.header.major_version}.#{pdf.header.minor_version})")

                no = 1
                pdf.revisions.each { |revision|
                    load_revision(root, no, revision)
                    no = no + 1
                }

                set_model(@treestore)

            ensure
                expand(@treestore.iter_first, 3)
                set_cursor(@treestore.iter_first.path, nil, false)
            end
        end

        private

        def object_to_tree_pos(obj)

            # Locate the indirect object.
            root_obj = obj
            object_path = [ root_obj ]
            while root_obj.parent
                root_obj = root_obj.parent
                object_path.push(root_obj)
            end

            @treestore.each do |model, path, iter|
                current_obj = @treestore.get_value(iter, OBJCOL)

                # Load the intermediate nodes if necessary.
                if object_path.any?{|object| object.equal?(current_obj)}
                    load_sub_objects(iter, current_obj)
                end

                # Unfold the object stream if it's in the object path.
                if obj.is_a?(Origami::Object) and current_obj.is_a?(Origami::ObjectStream) and
                   root_obj.equal?(current_obj) and iter.n_children == 1

                    current_obj.each { |embeddedobj|
                        load_object(iter, embeddedobj)
                    }
                end

                return [ iter, path ] if obj.equal?(current_obj)
            end

            nil
        end

        def expand(row, depth)
            if row and depth != 0
                loop do
                    expand_row(row.path, false)
                    expand(row.first_child, depth - 1)

                    break if not row.next!
                end
            end
        end

        def load_revision(root, no, revision)
            revroot = @treestore.append(root)
            @treestore.set_value(revroot, OBJCOL, revision)

            set_node(revroot, :Revision, "Revision #{no}")

            load_body(revroot, revision.body.values)
            load_xrefs(revroot, revision.xreftable)
            load_trailer(revroot, revision.trailer)
        end

        def load_body(rev, body)
            bodyroot = @treestore.append(rev)
            @treestore.set_value(bodyroot, OBJCOL, body)

            set_node(bodyroot, :Body, "Body")

            body.sort_by{|obj| obj.file_offset.to_i }.each { |object|
                begin
                    load_object(bodyroot, object)
                rescue
                    msg = "#{$!.class}: #{$!.message}\n#{$!.backtrace.join($/)}"
                    STDERR.puts(msg)

                    #@parent.error(msg)
                    next
                end
            }
        end

        def load_object(container, object, depth = 1, name = nil)
            iter = @treestore.append(container)
            @treestore.set_value(iter, OBJCOL, object)

            type = object.native_type.to_s.split('::').last.to_sym

            if name.nil?
                name =
                    case object
                    when Origami::String
                        '"' + object.to_utf8.gsub("\x00", ".") + '"'
                    when Origami::Number, Origami::Name
                        object.value.to_s
                    else
                        object.type.to_s
                    end
            end

            set_node(iter, type, name)
            return unless depth > 0

            load_sub_objects(iter, object, depth)
        end

        def load_sub_objects(container, object, depth = 1)
            return unless depth > 0 and @treestore.get_value(container, LOADCOL) != 1

            case object
            when Origami::Array
                object.each do |subobject|
                    load_object(container, subobject, depth - 1)
                end

            when Origami::Dictionary
                object.each_key do |subkey|
                    load_object(container, object[subkey.value], depth - 1, subkey.value.to_s)
                end

            when Origami::Stream
                load_object(container, object.dictionary, depth - 1, "Stream Dictionary")
            end

            @treestore.set_value(container, LOADCOL, 1)
        end

        def load_xrefstm(stm, embxref)
            xref = @treestore.append(stm)
            @treestore.set_value(xref, OBJCOL, embxref)

            if embxref.is_a?(Origami::XRef)
                set_node(xref, :XRef, embxref.to_s.chomp)
            else
                set_node(xref, :XRef, "xref to ObjectStream #{embxref.objstmno}, object index #{embxref.index}")
            end
        end

        def load_xrefs(rev, table)
            return unless table

            section = @treestore.append(rev)
            @treestore.set_value(section, OBJCOL, table)

            set_node(section, :XRefSection, "XRef section")

            table.each_subsection { |subtable|
                subsection = @treestore.append(section)
                @treestore.set_value(subsection, OBJCOL, subtable)

                set_node(subsection, :XRefSubSection, "#{subtable.range.begin} #{subtable.range.end - subtable.range.begin + 1}")

                subtable.each { |entry|
                    xref = @treestore.append(subsection)
                    @treestore.set_value(xref, OBJCOL, entry)

                    set_node(xref, :XRef, entry.to_s.chomp)
                }
            }
        end

        def load_trailer(rev, trailer)
            trailer_root = @treestore.append(rev)
            @treestore.set_value(trailer_root, OBJCOL, trailer)

            set_node(trailer_root, :Trailer, "Trailer")
            load_object(trailer_root, trailer.dictionary) unless trailer.dictionary.nil?
        end

        def reset_appearance
            @@appearance[:Filename] = {Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:Header] = {Color: "darkgreen", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:Revision] = {Color: "blue", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:Body] = {Color: "purple", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:XRefSection] = {Color: "purple", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:XRefSubSection] = {Color: "brown", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:XRef] = {Color: "gray20", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:Trailer] = {Color: "purple", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:StartXref] = {Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:String] = {Color: "red", Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_ITALIC}
            @@appearance[:Name] = {Color: "gray", Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_ITALIC}
            @@appearance[:Number] = {Color: "orange", Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_NORMAL}
            @@appearance[:Dictionary] = {Color: "brown", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:Stream] = {Color: "darkcyan", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:StreamData] = {Color: "darkcyan", Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_OBLIQUE}
            @@appearance[:Array] = {Color: "darkgreen", Weight: Pango::WEIGHT_BOLD, Style: Pango::STYLE_NORMAL}
            @@appearance[:Reference] = {Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_OBLIQUE}
            @@appearance[:Boolean] = {Color: "deeppink", Weight: Pango::WEIGHT_NORMAL, Style: Pango::STYLE_NORMAL}
        end

        def get_object_appearance(type)
            @@appearance[type]
        end

        def set_node(node, type, text)
            @treestore.set_value(node, TEXTCOL, text)

            app = get_object_appearance(type)
            @treestore.set_value(node, WEIGHTCOL, app[:Weight])
            @treestore.set_value(node, STYLECOL, app[:Style])
            @treestore.set_value(node, FGCOL, app[:Color])
        end
    end

end
