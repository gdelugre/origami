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

        def create_objectview
            @objectview = ObjectView.new(self)
        end

        class ObjectView < Notebook
            attr_reader :parent
            attr_reader :pdfpanel, :valuepanel

            def initialize(parent)
                @parent = parent
                super()

                @pdfbuffer = TextBuffer.new
                @pdfview = TextView.new(@pdfbuffer).set_editable(false).set_cursor_visible(false).set_left_margin(5)

                @pdfpanel = ScrolledWindow.new.set_policy(POLICY_AUTOMATIC, POLICY_AUTOMATIC)
                @pdfpanel.add_with_viewport @pdfview
                append_page(@pdfpanel, Label.new("PDF Code"))

                @pdfbuffer.create_tag("Default",
                    weight: Pango::WEIGHT_BOLD,
                    family: "monospace",
                    scale: Pango::AttrScale::LARGE
                )
            end

            def load(object)
                begin
                    self.clear

                    case object
                    when Origami::PDF::Header, Origami::FDF::Header, Origami::PPKLite::Header
                        text = object.to_s
                        @pdfbuffer.set_text(text)
                        @pdfbuffer.apply_tag("Default", @pdfbuffer.start_iter, @pdfbuffer.end_iter)

                    when Origami::Object
                        if object.is_a?(Origami::Stream)
                            text = [ "#{object.no} #{object.generation} obj", object.dictionary ].join($/)
                        else
                            text = object.to_s
                        end

                        text.encode!("UTF-8", replace: '.')
                            .tr!("\x00", '.')

                        @pdfbuffer.set_text(text)
                        @pdfbuffer.apply_tag("Default", @pdfbuffer.start_iter, @pdfbuffer.end_iter)
                    end

                rescue
                    @parent.error("An error occured while loading this object.\n#{$!} (#{$!.class})")
                end
            end

            def clear
                @pdfbuffer.set_text("")
            end
        end
    end

end
