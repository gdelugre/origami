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

    This work has been derived from the GHex project. Thanks to them.
    Original implementation: Jaka Mocnik <jaka@gnu.org>
=end

require 'gtk2'

module Gtk

    class HexEditor < Fixed
        module View
            HEX = 1
            ASCII = 2
        end

        module Group
            BYTE = 1
            WORD = 2
            LONG = 4
        end

        class Highlight
            attr_accessor :start, :end
            attr_accessor :start_line, :end_line
            attr_accessor :style
            attr_accessor :min_select
            attr_accessor :valid
        end

        class AutoHighlight
            attr_accessor :search_view
            attr_accessor :search_string
            attr_accessor :search_len

            attr_accessor :color

            attr_accessor :view_min
            attr_accessor :view_max

            attr_accessor :highlights
        end

        DEFAULT_FONT = "Monospace 12"
        DEFAULT_CPL = 32
        DEFAULT_LINES = 16
        DISPLAY_BORDER = 4
        SCROLL_TIMEOUT = 100

        type_register

        @@primary = Clipboard.get(Gdk::Selection::PRIMARY)
        @@clipboard = Clipboard.get(Gdk::Selection::CLIPBOARD)

        def initialize(data = '')
            super()

            @data = data.force_encoding('binary')

            @scroll_timeout = -1
            @disp_buffer = ""
            @starting_offset = 0

            @xdisp_width = @adisp_width = 200
            @xdisp_gc = @adisp_gc = nil
            @active_view = View::HEX
            @group_type = Group::BYTE
            @lines = @vis_lines = @top_line = @cpl = 0
            @cursor_pos = 0
            @lower_nibble = false
            @cursor_shown = false
            @button = 0
            @insert = false
            @selecting = false

            @selection = Highlight.new
            @selection.start = @selection.end = 0
            @selection.style = nil
            @selection.min_select = 1
            @selection.valid = false

            @highlights = [ @selection ]

            @auto_highlight = nil

            @disp_font_metrics = load_font DEFAULT_FONT
            @font_desc = Pango::FontDescription.new DEFAULT_FONT

            @char_width = get_max_char_width(@disp_font_metrics)
            @char_height = Pango.pixels(@disp_font_metrics.ascent) + Pango.pixels(@disp_font_metrics.descent) + 2

            @show_offsets = false
            @offsets_gc = nil

            self.can_focus = true
            self.events = Gdk::Event::KEY_PRESS_MASK
            self.border_width = DISPLAY_BORDER

            mouse_handler = lambda do |widget, event|
                if event.event_type == Gdk::Event::BUTTON_RELEASE and event.button == 1
                    if @scroll_timeout
                        GLib::Source.remove @scroll_timeout
                        @scroll_timeout = nil
                        @scroll_dir = 0
                    end

                    @selecting = false
                    Gtk.grab_remove(widget)
                    @button = 0
                elsif event.event_type == Gdk::Event::BUTTON_PRESS and event.button == 1
                    self.grab_focus unless self.has_focus?

                    Gtk.grab_add(widget)
                    @button = event.button

                    focus_view = (widget == @xdisp) ? View::HEX : View::ASCII

                    if @active_view == focus_view
                        if @active_view == View::HEX
                            hex_to_pointer(event.x, event.y)
                        else
                            ascii_to_pointer(event.x, event.y)
                        end

                        unless @selecting
                            @selecting = true
                            set_selection(@cursor_pos, @cursor_pos)
                        end
                    else
                        hide_cursor
                        @active_view = focus_view
                        show_cursor
                    end
                elsif event.event_type == Gdk::Event::BUTTON_PRESS and event.button == 2
                    # TODO
                else
                    @button = 0
                end
            end

            @xdisp = DrawingArea.new
            @xdisp.modify_font @font_desc
            @xlayout = @xdisp.create_pango_layout('')
            @xdisp.events =
                Gdk::Event::EXPOSURE_MASK |
                Gdk::Event::BUTTON_PRESS_MASK |
                Gdk::Event::BUTTON_RELEASE_MASK |
                Gdk::Event::BUTTON_MOTION_MASK |
                Gdk::Event::SCROLL_MASK

            @xdisp.signal_connect 'realize' do
                @xdisp_gc = Gdk::GC.new(@xdisp.window)
                @xdisp_gc.set_exposures(true)
            end

            @xdisp.signal_connect 'expose_event' do |_xdisp, event|
                imin = (event.area.y / @char_height).to_i
                imax = ((event.area.y + event.area.height) / @char_height).to_i
                imax += 1 if (event.area.y + event.area.height).to_i % @char_height != 0

                imax = [ imax, @vis_lines ].min

                render_hex_lines(imin, imax)
            end

            @xdisp.signal_connect 'scroll_event' do |_xdisp, event|
                @scrollbar.event(event)
            end

            @xdisp.signal_connect 'button_press_event' do |xdisp, event|
                mouse_handler[xdisp, event]
            end

            @xdisp.signal_connect 'button_release_event' do |xdisp, event|
                mouse_handler[xdisp, event]
            end

            @xdisp.signal_connect 'motion_notify_event' do |xdisp, event|
                _w, x, y, _m = xdisp.window.pointer

                if y < 0
                    @scroll_dir = -1
                elsif y >= xdisp.allocation.height
                    @scroll_dir = 1
                else
                    @scroll_dir = 0
                end

                if @scroll_dir != 0
                    if @scroll_timeout == nil
                        @scroll_timeout = GLib::Timeout.add(SCROLL_TIMEOUT) {
                            if @scroll_dir < 0
                                set_cursor([ 0, @cursor_pos - @cpl ].max)
                            elsif @scroll_dir > 0
                                set_cursor([ @data.size - 1, @cursor_pos + @cpl ].min)
                            end

                            true
                        }
                        next
                    end
                else
                    if @scroll_timeout != nil
                        GLib::Source.remove @scroll_timeout
                        @scroll_timeout = nil
                    end
                end

                next if event.window != xdisp.window

                hex_to_pointer(x,y) if @active_view == View::HEX and @button == 1
            end

            put @xdisp, 0, 0
            @xdisp.show

            @adisp = DrawingArea.new
            @adisp.modify_font @font_desc
            @alayout = @adisp.create_pango_layout('')
            @adisp.events =
                Gdk::Event::EXPOSURE_MASK |
                Gdk::Event::BUTTON_PRESS_MASK |
                Gdk::Event::BUTTON_RELEASE_MASK |
                Gdk::Event::BUTTON_MOTION_MASK |
                Gdk::Event::SCROLL_MASK

            @adisp.signal_connect 'realize' do
                @adisp_gc = Gdk::GC.new(@adisp.window)
                @adisp_gc.set_exposures(true)
            end

            @adisp.signal_connect 'expose_event' do |_adisp, event|
                imin = (event.area.y / @char_height).to_i
                imax = ((event.area.y + event.area.height) / @char_height).to_i
                imax += 1 if (event.area.y + event.area.height).to_i % @char_height != 0

                imax = [ imax, @vis_lines ].min
                render_ascii_lines(imin, imax)
            end

            @adisp.signal_connect 'scroll_event' do |_adisp, event|
                @scrollbar.event(event)
            end

            @adisp.signal_connect 'button_press_event' do |adisp, event|
                mouse_handler[adisp, event]
            end

            @adisp.signal_connect 'button_release_event' do |adisp, event|
                mouse_handler[adisp, event]
            end

            @adisp.signal_connect 'motion_notify_event' do |adisp, event|
                _w, x, y, _m = adisp.window.pointer

                if y < 0
                    @scroll_dir = -1
                elsif y >= adisp.allocation.height
                    @scroll_dir = 1
                else
                    @scroll_dir = 0
                end

                if @scroll_dir != 0
                    if @scroll_timeout == nil
                        @scroll_timeout = GLib::Timeout.add(SCROLL_TIMEOUT) {
                            if @scroll_dir < 0
                                set_cursor([ 0, @cursor_pos - @cpl ].max)
                            elsif @scroll_dir > 0
                                set_cursor([ @data.size - 1, @cursor_pos + @cpl ].min)
                            end

                            true
                        }
                        next
                    end
                else
                    if @scroll_timeout != nil
                        GLib::Source.remove @scroll_timeout
                        @scroll_timeout = nil
                    end
                end

                next if event.window != adisp.window

                ascii_to_pointer(x,y) if @active_view == View::ASCII and @button == 1
            end

            put @adisp, 0, 0
            @adisp.show

            @adj = Gtk::Adjustment.new(0, 0, 0, 0, 0, 0)
            @scrollbar = Gtk::VScrollbar.new(@adj)
            @adj.signal_connect 'value_changed' do |adj|
                unless @xdisp_gc.nil? or @adisp_gc.nil? or not @xdisp.drawable? or not @adisp.drawable?
                    source_min = (adj.value.to_i - @top_line) * @char_height
                    source_max = source_min + @xdisp.allocation.height
                    dest_min = 0
                    dest_max = @xdisp.allocation.height

                    rect = Gdk::Rectangle.new(0, 0, 0, 0)
                    @top_line = adj.value.to_i
                    if source_min < 0
                        rect.y = 0
                        rect.height = -source_min
                        rect_height = [ rect.height, @xdisp.allocation.height ].min
                        source_min = 0
                        dest_min = rect.height
                    else
                        rect.y = 2 * @xdisp.allocation.height - source_max
                        rect.y = 0 if rect.y < 0
                        rect.height = @xdisp.allocation.height - rect.y
                        source_max = @xdisp.allocation.height
                        dest_max = rect.y
                    end

                    if source_min != source_max
                        @xdisp.window.draw_drawable(
                            @xdisp_gc,
                            @xdisp.window,
                            0, source_min,
                            0, dest_min,
                            @xdisp.allocation.width,
                            source_max - source_min
                        )
                        @adisp.window.draw_drawable(
                            @adisp_gc,
                            @adisp.window,
                            0, source_min,
                            0, dest_min,
                            @adisp.allocation.width,
                            source_max - source_min
                        )

                        if @offsets
                            if @offsets_gc.nil?
                                @offsets_gc = Gdk::GC.new(@offsets.window)
                                @offsets_gc.set_exposures(true)
                            end

                            @offsets.window.draw_drawable(
                                @offsets_gc,
                                @offsets.window,
                                0, source_min,
                                0, dest_min,
                                @offsets.allocation.width,
                                source_max - source_min
                            )
                        end

                        # TODO update_all_auto_highlights(true, true)
                        invalidate_all_highlights

                        rect.width = @xdisp.allocation.width
                        @xdisp.window.invalidate(rect, false)
                        rect.width = @adisp.allocation.width
                        @adisp.window.invalidate(rect, false)

                        if @offsets
                            rect.width = @offsets.allocation.width
                            @offsets.window.invalidate(rect, false)
                        end
                    end
                end
            end

            put @scrollbar, 0, 0
            @scrollbar.show
        end

        def set_selection(s, e)
            e = [ e, @data.size ].min

            @@primary.clear if @selection.start != @selection.end

            os, oe = [ @selection.start, @selection.end ].sort

            @selection.start = [ 0, s ].max
            @selection.start = [ @selection.start, @data.size ].min
            @selection.end = [ e, @data.size ].min

            invalidate_highlight(@selection)

            ns, ne = [ @selection.start, @selection.end ].sort

            if ns != os and ne != oe
                bytes_changed([ns, os].min, [ne, oe].max)
            elsif ne != oe
                bytes_changed(*[ne, oe].sort)
            elsif ns != os
                bytes_changed(*[ns, os].sort)
            end

            if @selection.start != @selection.end
                if @active_view == View::HEX
                    brk_len = 2 * @cpl + @cpl / @group_type
                    format_xblock(s,e)
                    (@disp_buffer.size / brk_len + 1).times do |i| @disp_buffer.insert(i * (brk_len + 1), $/) end
                else
                    brk_len = @cpl
                    format_ablock(s,e)
                end

                @@primary.set_text(@disp_buffer)
            end
        end

        def get_selection
            [ @selection.start, @selection.end ].sort
        end

        def clear_selection
            set_selection(0, 0)
        end

        def cursor
            @cursor_pos
        end

        def set_cursor(index)
            return if index < 0 or index > @data.size

            old_pos = @cursor_pos
            index -= 1 if @insert and index == @data.size
            index = [ 0, index ].max

            hide_cursor

            @cursor_pos = index
            return if @cpl == 0

            y = index / @cpl
            if y >= @top_line + @vis_lines
                @adj.value = [ y - @vis_lines + 1, @lines - @vis_lines ].min
                @adj.value = [ 0, @adj.value ].max
                @adj.signal_emit 'value_changed'
            elsif y < @top_line
                @adj.value = y
                @adj.signal_emit 'value_changed'
            end

            @lower_nibble = false if index == @data.size

            if @selecting
                set_selection(@selection.start, @cursor_pos)
                bytes_changed(*[@cursor_pos, old_pos].sort)
            else# @selection.start != @selection.end
                s, e = [@selection.start, @selection.end].sort
                @selection.end = @selection.start = @cursor_pos
                bytes_changed(s, e)
            end

            self.signal_emit 'cursor_moved'

            bytes_changed(old_pos, old_pos)
            show_cursor
        end

        def set_cursor_xy(x, y)
            pos = y.to_i * @cpl + x.to_i
            return if y < 0 or y >= @lines or x < 0 or x >= @cpl or pos > @data.size

            set_cursor(pos)
        end

        def set_cursor_on_lower_nibble(bool)
            if @selecting
                bytes_changed(@cursor_pos, @cursor_pos)
                @lower_nibble = bool
            elsif @selection.start != @selection.end
                s, e = [ @selection.start, @selection.end ].sort

                @selection.start = @selection.end = 0
                bytes_changed(s, e)
                @lower_nibble = bool
            else
                hide_cursor
                @lower_nibble = bool
                show_cursor
            end
        end

        def set_group_type(type)
            hide_cursor
            @group_type = type
            recalc_displays(self.allocation.width, self.allocation.height)
            self.queue_resize
            show_cursor
        end

        def show_offsets(bool)
            return unless @show_offsets ^ bool

            @show_offsets = bool
            if bool
                show_offsets_widget
            else
                hide_offsets_widget
            end
        end

        def set_font(fontname)
            @font_desc = Pango::FontDescription.new(fontname)
            @disp_font_metrics = load_font(fontname)

            @xdisp.modify_font(@font_desc) if @xdisp
            @adisp.modify_font(@font_desc) if @adisp
            @offsets.modify_font(@font_desc) if @offsets

            @char_width = get_max_char_width(@disp_font_metrics)
            @char_height = Pango.pixels(@disp_font_metrics.ascent) + Pango.pixels(@disp_font_metrics.descent) + 2
            recalc_displays(self.allocation.width, self.allocation.height)

            redraw_widget
        end

        def set_data(data)
            prev_data_size = @data.size
            @data = data.dup

            recalc_displays(self.allocation.width, self.allocation.height)

            set_cursor 0
            bytes_changed(0, [ prev_data_size, @data.size ].max)
            redraw_widget
        end

        def validate_highlight(hl)
            unless hl.valid
                hl.start_line = [ hl.start, hl.end ].min / @cpl - @top_line
                hl.end_line = [ hl.start, hl.end ].max / @cpl - @top_line
                hl.valid = true
            end
        end

        def invalidate_highlight(hl)
            hl.valid = false
        end

        def invalidate_all_highlights
            @highlights.each do |hl| invalidate_highlight(hl) end
        end

        private

        signal_new(
            'data_changed',
            GLib::Signal::RUN_FIRST,
            nil,
            nil,
            String
        )

        signal_new(
            'cursor_moved',
            GLib::Signal::RUN_FIRST,
            nil,
            nil
        )

        def signal_do_cursor_moved
        end

        def signal_do_data_changed(data)
            # TODO
        end

        def signal_do_realize
            super

            self.window.set_back_pixmap(nil, true)
        end

        def signal_do_size_allocate(alloc)
            hide_cursor

            recalc_displays(alloc.width, alloc.height)

            self.set_allocation(alloc.x, alloc.y, alloc.width, alloc.height)
            self.window.move_resize(
                alloc.x, alloc.y,
                alloc.width, alloc.height
            ) if self.realized?

            bw = self.border_width
            xt = widget_get_xt
            yt = widget_get_yt

            my_alloc = Gtk::Allocation.new(0, 0, 0, 0)
            my_alloc.x = bw + xt
            my_alloc.y = bw + yt
            my_alloc.height = [ alloc.height - 2*bw - 2*yt, 1 ].max
            if @show_offsets
                my_alloc.width = 8 * @char_width
                @offsets.size_allocate(my_alloc)
                @offsets.queue_draw
                my_alloc.x += 2*xt + my_alloc.width
            end

            my_alloc.width = @xdisp_width
            @xdisp.size_allocate(my_alloc)

            my_alloc.x = alloc.width - bw - @scrollbar.requisition[0]
            my_alloc.y = bw
            my_alloc.width = @scrollbar.requisition[0]
            my_alloc.height = [ alloc.height - 2*bw, 1 ].max
            @scrollbar.size_allocate(my_alloc)

            my_alloc.x -= @adisp_width + xt
            my_alloc.y = bw + yt
            my_alloc.width = @adisp_width
            my_alloc.height = [ alloc.height - 2*bw - 2*yt, 1 ].max
            @adisp.size_allocate(my_alloc)

            show_cursor
        end

        def signal_do_size_request(req)
            sb_width, _sb_height = @scrollbar.size_request
            bw = self.border_width
            xt, yt = widget_get_xt, widget_get_yt

            width = 4*xt + 2*bw + sb_width +
                @char_width*(DEFAULT_CPL + (DEFAULT_CPL-1)/@group_type)

            width += 2*xt + 8*@char_width if @show_offsets

            height = DEFAULT_LINES * @char_height + 2*yt + 2*bw

            req[0] = width
            req[1] = height
        end

        def signal_do_expose_event(event)
            draw_shadow(event.area)
            super(event)

            true
        end

        def signal_do_key_press_event(event)

            hide_cursor
            @selecting = (event.state & Gdk::Window::SHIFT_MASK) != 0
            ret = true

            case event.keyval
            when Gdk::Keyval::GDK_KP_Tab, Gdk::Keyval::GDK_Tab
                @active_view = (@active_view == View::HEX) ? View::ASCII : View::HEX

            when Gdk::Keyval::GDK_Up
                set_cursor(@cursor_pos - @cpl)

            when Gdk::Keyval::GDK_Down
                set_cursor(@cursor_pos + @cpl)

            when Gdk::Keyval::GDK_Page_Up
                set_cursor([0, @cursor_pos - @vis_lines * @cpl].max)

            when Gdk::Keyval::GDK_Page_Down
                set_cursor([@cursor_pos + @vis_lines * @cpl, @data.size].min)

            when Gdk::Keyval::GDK_Left
                if @active_view == View::HEX
                    if @selecting
                        set_cursor(@cursor_pos - 1)
                    else
                        @lower_nibble ^= 1
                        set_cursor(@cursor_pos - 1) if @lower_nibble
                    end
                else
                    set_cursor(@cursor_pos - 1)
                end

            when Gdk::Keyval::GDK_Right
                if @active_view == View::HEX
                    if @selecting
                        set_cursor(@cursor_pos + 1)
                    else
                        @lower_nibble ^= 1
                        set_cursor(@cursor_pos + 1) unless @lower_nibble
                    end
                else
                    set_cursor(@cursor_pos + 1)
                end

            when Gdk::Keyval::GDK_c, Gdk::Keyval::GDK_C
                if event.state & Gdk::Window::CONTROL_MASK != 0
                    s,e  = @selection.start, @selection.end + 1
                    if @active_view == View::HEX
                        brk_len = 2 * @cpl + @cpl / @group_type
                        format_xblock(s,e)
                        (@disp_buffer.size / brk_len + 1).times do |i| @disp_buffer.insert(i * (brk_len + 1), $/) end
                    else
                        brk_len = @cpl
                        format_ablock(s,e)
                    end

                    @@clipboard.set_text(@disp_buffer)
                end
            else
                ret = false
            end

            show_cursor

            ret
        end

        def hex_to_pointer(mx, my)
            cy = @top_line + my.to_i / @char_height

            cx = x = 0
            while cx < 2 * @cpl
                x += @char_width

                if x > mx
                    set_cursor_xy(cx / 2, cy)
                    set_cursor_on_lower_nibble(cx % 2 != 0)

                    cx = 2 * @cpl
                end

                cx += 1
                x += @char_width if ( cx % (2 * @group_type) == 0 )
            end
        end

        def ascii_to_pointer(mx, my)
            cx = mx / @char_width
            cy = @top_line + my / @char_height

            set_cursor_xy(cx, cy)
        end

        def load_font(fontname)
            desc = Pango::FontDescription.new(fontname)
            context = Gdk::Pango.context
            context.set_language(Gtk.default_language)

            font = context.load_font(desc)

            font.metrics(context.language)
        end

        def draw_shadow(area)
            bw = self.border_width
            x = bw
            xt = widget_get_xt

            if @show_offsets
                self.style.paint_shadow(
                    self.window,
                    Gtk::STATE_NORMAL, Gtk::SHADOW_IN,
                    nil, self, nil,
                    bw, bw,
                    8*@char_width + 2*xt, self.allocation.height - 2*bw
                )

                x += 8*@char_width + 2*xt
            end

            self.style.paint_shadow(
                self.window,
                Gtk::STATE_NORMAL, Gtk::SHADOW_IN,
                nil, self, nil,
                x, bw,
                @xdisp_width + 2*xt, self.allocation.height - 2*bw
            )

            self.style.paint_shadow(
                self.window,
                Gtk::STATE_NORMAL, Gtk::SHADOW_IN,
                nil, self, nil,
                self.allocation.width - bw - @adisp_width - @scrollbar.requisition[0] - 2*xt, bw,
                @adisp_width + 2*xt, self.allocation.height - 2*bw
            )
        end

        def redraw_widget
            return unless self.realized?

            self.window.invalidate(nil, false)
        end

        def widget_get_xt
            self.style.xthickness
        end

        def widget_get_yt
            self.style.ythickness
        end

        def recalc_displays(width, height)
            old_cpl = @cpl

            w, _h = @scrollbar.size_request
            @xdisp_width = 1
            @adisp_width = 1

            total_width = width - 2 * self.border_width - 4 * widget_get_xt - w
            total_width -= 2 * widget_get_xt + 8 * @char_width if @show_offsets

            total_cpl = total_width / @char_width
            if total_cpl == 0 or total_width < 0
                @cpl = @lines = @vis_lines = 0
                return
            end

            @cpl = 0
            begin
                break if @cpl % @group_type == 0 and total_cpl < @group_type * 3

                @cpl += 1
                total_cpl -= 3

                total_cpl -= 1 if @cpl % @group_type == 0
            end while total_cpl > 0

            return if @cpl == 0

            if @data.empty?
                @lines = 1
            else
                @lines = @data.size / @cpl
                @lines += 1 if @data.size % @cpl != 0
            end

            @vis_lines = (height - 2*self.border_width - 2*widget_get_yt).to_i / @char_height.to_i
            @adisp_width = @cpl * @char_width + 1
            xcpl = @cpl * 2 + (@cpl - 1) / @group_type
            @xdisp_width = xcpl * @char_width + 1

            @disp_buffer = ''

            @adj.value = [@top_line * old_cpl / @cpl, @lines - @vis_lines].min
            @adj.value = [ 0, @adj.value ].max
            if @cursor_pos / @cpl < @adj.value or @cursor_pos / @cpl > @adj.value + @vis_lines - 1
                @adj.value = [ @cursor_pos / @cpl, @lines - @vis_lines ].min
                @adj.value = [ 0, @adj.value ].max
            end

            @adj.lower = 0
            @adj.upper = @lines
            @adj.step_increment = 1
            @adj.page_increment = @vis_lines - 1
            @adj.page_size = @vis_lines

            @adj.signal_emit 'changed'
            @adj.signal_emit 'value_changed'
        end

        def get_max_char_width(metrics)
            layout = self.create_pango_layout('')
            layout.set_font_description(@font_desc)
            char_widths = [ 0 ]

            (1..100).each do |i|
                logical_rect = Pango::Rectangle.new(0, 0, 0, 0)
                if is_displayable(i.chr)
                    layout.set_text(i.chr)
                    logical_rect = layout.pixel_extents[1]
                end
                char_widths << logical_rect.width
            end

            char_widths[48..122].max
        end

        def show_cursor
            unless @cursor_shown
                if @xdisp_gc and @adisp_gc and @xdisp.realized? and @adisp.realized?
                    render_xc
                    render_ac
                end

                @cursor_shown = true
            end
        end

        def hide_cursor
            if @cursor_shown
                if @xdisp_gc and @adisp_gc and @xdisp.realized? and @adisp.realized?
                    render_byte(@cursor_pos)
                end

                @cursor_shown = false
            end
        end

        def show_offsets_widget
            @offsets = DrawingArea.new
            @offsets.modify_font @font_desc
            @olayout = @offsets.create_pango_layout('')

            @offsets.events = Gdk::Event::EXPOSURE_MASK
            @offsets.signal_connect 'expose_event' do |_offsets, event|
                imin = (event.area.y / @char_height).to_i
                imax = ((event.area.y + event.area.height) / @char_height).to_i
                imax += 1 if (event.area.y + event.area.height).to_i % @char_height != 0

                imax = [ imax, @vis_lines ].min

                render_offsets(imin, imax)
            end

            put @offsets, 0, 0
            @offsets.show
        end

        def hide_offsets_widget
            if @offsets
                self.remove(@offsets)
                @offsets = @offsets_gc = nil
            end
        end

        def is_displayable(c)
            c = c.ord
            c >= 0x20 and c < 0x7f
        end

        def bytes_changed(s, e)
            start_line = s / @cpl - @top_line
            end_line = e / @cpl - @top_line

            return if end_line < 0 or start_line > @vis_lines

            start_line = [ 0, start_line ].max

            render_hex_lines(start_line, end_line)
            render_ascii_lines(start_line, end_line)
            render_offsets(start_line, end_line) if @show_offsets
        end

        def render_hex_highlights(cursor_line)
            xcpl = @cpl * 2 + @cpl / @group_type

            @highlights.each do |hl|
                next if (hl.start - hl.end).abs < hl.min_select

                validate_highlight(hl)

                s, e = [ hl.start, hl.end ].sort
                sl, el = hl.start_line, hl.end_line

                hl.style.attach(@xdisp.window) if hl.style
                state = (@active_view == View::HEX) ? Gtk::STATE_SELECTED : Gtk::STATE_INSENSITIVE

                if cursor_line == sl
                    cursor_off = 2 * (s % @cpl) + (s % @cpl) / @group_type
                    if cursor_line == el
                        len = 2 * (e % @cpl + 1) + (e % @cpl) / @group_type
                    else
                        len = xcpl
                    end

                    len -= cursor_off
                    (hl.style || self.style).paint_flat_box(
                        @xdisp.window,
                        state, Gtk::SHADOW_NONE,
                        nil, @xdisp, '',
                        cursor_off * @char_width, cursor_line * @char_height,
                        len * @char_width, @char_height
                    ) if len > 0

                elsif cursor_line == el
                    cursor_off = 2 * (e % @cpl + 1) + (e % @cpl) / @group_type
                    (hl.style || self.style).paint_flat_box(
                        @xdisp.window,
                        state, Gtk::SHADOW_NONE,
                        nil, @xdisp, '',
                        0, cursor_line * @char_height,
                        cursor_off * @char_width, @char_height
                    ) if cursor_off > 0

                elsif cursor_line > sl and cursor_line < el
                    (hl.style || self.style).paint_flat_box(
                        @xdisp.window,
                        state, Gtk::SHADOW_NONE,
                        nil, @xdisp, '',
                        0, cursor_line * @char_height,
                        xcpl * @char_width, @char_height
                    )
                end

                hl.style.attach(@adisp.window) if hl.style
            end
        end

        def render_hex_lines(imin, imax)
            return unless self.realized? and @cpl != 0

            cursor_line = @cursor_pos / @cpl - @top_line

            @xdisp_gc.set_foreground(self.style.base(Gtk::STATE_NORMAL))
            @xdisp.window.draw_rectangle(
                @xdisp_gc,
                true,
                0,
                imin * @char_height,
                @xdisp.allocation.width,
                (imax - imin + 1) * @char_height
            )

            imax = [ imax, @vis_lines, @lines ].min

            @xdisp_gc.set_foreground(self.style.text(Gtk::STATE_NORMAL))

            frm_len = format_xblock((@top_line+imin) * @cpl, [(@top_line+imax+1) * @cpl, @data.size].min)

            tmp = nil
            xcpl = @cpl*2 + @cpl/@group_type
            (imin..imax).each do |i|
                return unless (tmp = frm_len - ((i - imin) * xcpl)) > 0

                render_hex_highlights(i)
                text = @disp_buffer[(i-imin) * xcpl, [xcpl, tmp].min]
                @xlayout.set_text(text)
                @xdisp.window.draw_layout(@xdisp_gc, 0, i * @char_height, @xlayout)
            end

            render_xc if cursor_line >= imin and cursor_line <= imax and @cursor_shown
        end

        def render_ascii_highlights(cursor_line)
            @highlights.each do |hl|
                next if (hl.start - hl.end).abs < hl.min_select

                validate_highlight(hl)

                s, e = [ hl.start, hl.end ].sort
                sl, el = hl.start_line, hl.end_line

                hl.style.attach(@adisp.window) if hl.style
                state = (@active_view == View::ASCII) ? Gtk::STATE_SELECTED : Gtk::STATE_INSENSITIVE

                if cursor_line == sl
                    cursor_off = s % @cpl
                    len =
                        if cursor_line == el
                            e - s + 1
                        else
                            @cpl - cursor_off
                        end

                    (hl.style || self.style).paint_flat_box(
                        @adisp.window,
                        state, Gtk::SHADOW_NONE,
                        nil, @adisp, '',
                        cursor_off * @char_width, cursor_line * @char_height,
                        len * @char_width, @char_height
                    ) if len > 0

                elsif cursor_line == el
                    cursor_off = e % @cpl + 1
                    (hl.style || self.style).paint_flat_box(
                        @adisp.window,
                        state, Gtk::SHADOW_NONE,
                        nil, @adisp, '',
                        0, cursor_line * @char_height,
                        cursor_off * @char_width, @char_height
                    ) if cursor_off > 0

                elsif cursor_line > sl and cursor_line < el
                    (hl.style || self.style).paint_flat_box(
                        @adisp.window,
                        state, Gtk::SHADOW_NONE,
                        nil, @adisp, '',
                        0, cursor_line * @char_height,
                        @cpl * @char_width, @char_height
                    )
                end

                hl.style.attach(@adisp.window) if hl.style
            end
        end

        def render_ascii_lines(imin, imax)
            return unless self.realized? and @cpl != 0

            cursor_line = @cursor_pos / @cpl - @top_line

            @adisp_gc.set_foreground(self.style.base(Gtk::STATE_NORMAL))
            @adisp.window.draw_rectangle(
                @adisp_gc,
                true,
                0,
                imin * @char_height,
                @adisp.allocation.width,
                (imax - imin + 1) * @char_height
            )

            imax = [ imax, @vis_lines, @lines ].min

            @adisp_gc.set_foreground(self.style.text(Gtk::STATE_NORMAL))

            frm_len = format_ablock((@top_line+imin) * @cpl, [(@top_line+imax+1) * @cpl, @data.size].min)

            tmp = nil
            (imin..imax).each do |i|
                return unless (tmp = frm_len - ((i - imin) * @cpl)) > 0

                render_ascii_highlights(i)
                text = @disp_buffer[(i-imin) * @cpl, [@cpl, tmp].min]
                @alayout.set_text(text)
                @adisp.window.draw_layout(@adisp_gc, 0, i * @char_height, @alayout)
            end

            render_ac if cursor_line >= imin and cursor_line <= imax and @cursor_shown
        end

        def render_offsets(imin, imax)
            return unless self.realized?

            unless @offsets_gc
                @offsets_gc = Gdk::GC.new(@offsets.window)
                @offsets_gc.set_exposures(true)
            end

            @offsets_gc.set_foreground(self.style.base(Gtk::STATE_INSENSITIVE))
                @offsets.window.draw_rectangle(
                @offsets_gc,
                true,
                0, imin * @char_height,
                @offsets.allocation.width, (imax - imin + 1) * @char_height
            )

            imax = [ imax, @vis_lines, @lines - @top_line - 1 ].min
            @offsets_gc.set_foreground(self.style.text(Gtk::STATE_NORMAL))

            (imin..imax).each do |i|
                text = "%08x" % ((@top_line + i) * @cpl + @starting_offset)
                @olayout.set_text(text)
                @offsets.window.draw_layout(@offsets_gc, 0, i * @char_height, @olayout)
            end
        end

        def render_byte(pos)
            return unless @xdisp_gc and @adisp_gc and @xdisp.realized? and @adisp.realized?

            return unless (coords = get_xcoords(pos))
            cx, cy = coords
            c = format_xbyte(pos)

            @xdisp_gc.set_foreground(self.style.base(Gtk::STATE_NORMAL))
            @xdisp.window.draw_rectangle(
                @xdisp_gc,
                true,
                cx, cy,
                2 * @char_width, @char_height
            )

            if pos < @data.size
                @xdisp_gc.set_foreground(self.style.text(Gtk::STATE_NORMAL))
                @xlayout.set_text(c)
                @xdisp.window.draw_layout(@xdisp_gc, cx, cy, @xlayout)
            end

            return unless (coords = get_acoords(pos))
            cx, cy = coords

            @adisp_gc.set_foreground(self.style.base(Gtk::STATE_NORMAL))
            @adisp.window.draw_rectangle(
                @adisp_gc,
                true,
                cx, cy,
                @char_width, @char_height
            )

            if pos < @data.size
                @adisp_gc.set_foreground(self.style.text(Gtk::STATE_NORMAL))
                c = get_byte(pos)
                c = '.' unless is_displayable(c)

                @alayout.set_text(c)
                @adisp.window.draw_layout(@adisp_gc, cx, cy, @alayout)
            end
        end

        def render_xc
            return unless @xdisp.realized?

            if coords = get_xcoords(@cursor_pos)
                cx, cy = coords

                c = format_xbyte(@cursor_pos)
                if @lower_nibble
                    cx += @char_width
                    c = c[1,1]
                else
                    c = c[0,1]
                end

                @xdisp_gc.set_foreground(self.style.base(Gtk::STATE_ACTIVE))
                @xdisp.window.draw_rectangle(
                    @xdisp_gc,
                    (@active_view == View::HEX),
                    cx, cy,
                    @char_width,
                    @char_height - 1
                )
                @xdisp_gc.set_foreground(self.style.text(Gtk::STATE_ACTIVE))
                @xlayout.set_text(c)
                @xdisp.window.draw_layout(@xdisp_gc, cx, cy, @xlayout)
            end
        end

        def render_ac
            return unless @adisp.realized?

            if coords = get_acoords(@cursor_pos)
                cx, cy = coords

                c = get_byte(@cursor_pos)
                c = '.' unless is_displayable(c)

                @adisp_gc.set_foreground(self.style.base(Gtk::STATE_ACTIVE))
                @adisp.window.draw_rectangle(
                    @adisp_gc,
                    (@active_view == View::ASCII),
                    cx, cy,
                    @char_width,
                    @char_height - 1
                )
                @adisp_gc.set_foreground(self.style.text(Gtk::STATE_ACTIVE))
                @alayout.set_text(c)
                @adisp.window.draw_layout(@adisp_gc, cx, cy, @alayout)
            end
        end

        def get_xcoords(pos)
            return nil if @cpl == 0

            cy = pos / @cpl - @top_line
            return nil if cy < 0

            cx = 2 * (pos % @cpl)
            spaces = (pos % @cpl) / @group_type

            cx *= @char_width
            cy *= @char_height
            spaces *= @char_width

            [cx + spaces, cy]
        end

        def get_acoords(pos)
            return nil if @cpl == 0

            cy = pos / @cpl - @top_line
            return nil if cy < 0

            cy *= @char_height
            cx = @char_width * (pos % @cpl)

            [cx, cy]
        end

        def format_xblock(s, e)
            @disp_buffer = ''

            (s+1..e).each do |i|
                @disp_buffer << get_byte(i - 1).unpack('H2')[0]
                @disp_buffer << ' ' if i % @group_type == 0
            end

            @disp_buffer.size
        end

        def format_ablock(s, e)
            @disp_buffer = ''

            (s..e-1).each do |i|
                c = get_byte(i)
                c = '.' unless is_displayable(c)
                @disp_buffer << c
            end

            @disp_buffer.size
        end

        def get_byte(offset)
            if offset >= 0 and offset < @data.size
                @data[offset, 1]
            else
                0.chr
            end
        end

        def format_xbyte(pos)
            get_byte(pos).unpack('H2')[0]
        end
    end
end

__END__
hexedit = Gtk::HexEditor.new(File.read '/bin/cat')
hexedit.show_offsets(true)
hexedit.set_cursor 2
hexedit.set_cursor_on_lower_nibble true
hexedit.set_font 'Terminus 12'
hexedit.set_group_type Gtk::HexEditor::Group::LONG

window = Gtk::Window.new
window.add(hexedit)

window.show_all

Gtk.main
