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

    class ImgViewer < Window
        attr_reader :image

        def initialize
            super()

            set_title "Image view"
            set_decorated false
            set_resizable false

            add_events(Gdk::Event::KEY_RELEASE_MASK)
            signal_connect('key_release_event') { |_, event|
                destroy if event.keyval == Gdk::Keyval::GDK_Escape
            }
        end

        def show_raw_img(data, w, h, bpc, bpr)
            set_default_size w,h

            pixbuf = GdkPixbuf::Pixbuf.new data: data,
                        colorspace: GdkPixbuf::Colorspace::RGB,
                        has_alpha: false,
                        bits_per_sample: bpc,
                        width: w, height: h,
                        row_stride: bpr

            @image = Gtk::Image.new(pixbuf)
            add @image

            show_all
        end

        def show_compressed_img(data)
            loader = Gdk::PixbufLoader.new
            loader.last_write data

            pixbuf = loader.pixbuf
            set_default_size pixbuf.width, pixbuf.height

            @image = Gtk::Image.new(pixbuf)
            add @image

            show_all
        end
    end

end
