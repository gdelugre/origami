=begin

    This file is part of Origami, PDF manipulation framework for Ruby
    Copyright (C) 2016	Guillaume Delugré.

    Origami is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Origami is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Origami.  If not, see <http://www.gnu.org/licenses/>.

=end

module Origami

    module Template

        class Button < Annotation::Widget::PushButton
            def initialize(caption, id: nil, x:, y:, width:, height:)
                super()

                set_indirect(true)

                self.set_name(id)
                self.H = Annotation::Widget::Highlight::INVERT
                self.Rect = [ x, y, x + width, y + height ]
                self.F = Annotation::Flags::PRINT

                appstm = Annotation::AppearanceStream.new.setFilter(:FlateDecode)
                appstm.BBox = [ 0, 0, width, height ]
                appstm.Matrix = [ 1, 0, 0, 1, 0, 0 ]

                appstm.draw_rectangle(0, 0, width, height,
                    fill: true, stroke: false, fill_color: Graphics::Color::RGB.new(0xE6, 0xE6, 0xFA))

                appstm.draw_polygon([[1,1],[1,height-1],[width-1,height-1],[width-2,height-2],[2,height-2],[2,2]],
                    fill: true, stroke: false, fill_color: Graphics::Color::GrayScale.new(1.0))

                appstm.draw_polygon([[width-1,height-1],[width-1,1],[1,1],[2,2],[width-2,2],[width-2,height-2]],
                    fill: true, stroke: false, fill_color: Graphics::Color::RGB.new(130, 130, 130))

                appstm.draw_rectangle(0.5, 0.5, width-1, height-1,
                    fill: false, stroke: true, stroke_color: Graphics::Color::GrayScale.new(0.0))

                text_width = 4.75 * caption.length
                appstm.write(caption,
                    x: (width - text_width)/2, y: height/2-5, size: 10)

                appstm.Resources = Resources.new
                set_normal_appearance(appstm)
            end
        end

        class Edit < Annotation::Widget::Text
            def initialize(id, x:, y:, width:, height:)
                super()

                set_indirect(true)

                self.set_name(id)
                self.Rect = [ x, y, x+width, y+height ]
                self.F = Annotation::Flags::PRINT
                self.DA = '/F1 12 Tf 0 g'

                appstm = Annotation::AppearanceStream.new.setFilter(:FlateDecode)
                appstm.BBox = [ 0, 0, width, height ]
                appstm.Matrix = [ 1, 0, 0, 1, 0, 0 ]

                appstm.draw_rectangle(0, 0, width, height,
                    fill: false, stroke: true, stroke_color: Graphics::Color::GrayScale.new(0.0))

                appstm.draw_polygon([[1,1],[1,height-1],[width-1,height-1],[width-2,height-2],[2,height-2],[2,2]],
                    fill: true, stroke: false, fill_color: Graphics::Color::RGB.new(130, 130, 130))

                appstm.draw_polygon([[width-1,height-1],[width-1,1],[1,1],[2,2],[width-2,2],[width-2,height-2]],
                    fill: true, stroke: false, fill_color: Graphics::Color::GrayScale.new(1.0))

                appstm.draw_rectangle(0.5, 0.5, width-1, height-1,
                    fill: false, stroke: true, stroke_color: Graphics::Color::GrayScale.new(0.0))

                set_normal_appearance(appstm)
            end
        end

        class MultiLineEdit < Edit
            def initialize(id, x:, y:, width:, height:)
                super(id, x: x, y: y, width: width, height: height)

                self.Ff ||= 0
                self.Ff |= Annotation::Widget::Text::Flags::MULTILINE
            end
        end

        class RichTextEdit < MultiLineEdit
            def initialize(id, x: , y:, width:, height:)
                super(id, x: x, y: y, width: width, height: height)

                self.F |= Annotation::Flags::READONLY
                self.Ff |= (Annotation::Widget::Text::Flags::RICHTEXT | Field::Flags::READONLY)
            end
        end

        class PasswordEdit < Edit
            def initialize(id, x:, y:, width:, height:)
                super(id, x: x, y: y, width: width, height: height)

                self.Ff ||= 0
                self.Ff |= Annotation::Widget::Text::Flags::PASSWORD
            end
        end

        class TextPanel < Annotation::FreeText
            def initialize(id, x:, y:, width:, height:)
                super()

                set_indirect(true)

                self.Rect = [ x, y, x + width, y + height ]
                self.F = Annotation::Flags::PRINT
                self.NM = id
                self.DA = '/F1 12 Tf 0 g'

                appstm = Annotation::AppearanceStream.new.setFilter(:FlateDecode)
                appstm.BBox = [ 0, 0, width, height ]
                appstm.Matrix = [ 1, 0, 0, 1, 0, 0 ]

                appstm.draw_rectangle(0, 0, width, height,
                    fill: false, stroke: true, stroke_color: Graphics::Color::GrayScale.new(0.0))

                appstm.draw_polygon([[1,1],[1,height-1],[width-1,height-1],[width-2,height-2],[2,height-2],[2,2]],
                    fill: true, stroke: false, fill_color: Graphics::Color::RGB.new(130, 130, 130))

                appstm.draw_polygon([[width-1,height-1],[width-1,1],[1,1],[2,2],[width-2,2],[width-2,height-2]],
                    fill: true, stroke: false, fill_color: Graphics::Color::GrayScale.new(1.0))

                appstm.draw_rectangle(0.5, 0.5, width-1, height-1,
                    fill: false, stroke: true, stroke_color: Graphics::Color::GrayScale.new(0.0))

                set_normal_appearance(appstm)
            end
        end
    end

end
