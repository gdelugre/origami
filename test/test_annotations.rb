require 'minitest/autorun'
require 'stringio'

class TestAnnotations < Minitest::Test
    def setup
        @target = PDF.new
        @page = Page.new
        @action = Action::JavaScript["app.alert(null);"]
        @output = StringIO.new
    end

    def test_annotations
        circle = Annotation::Circle.new
        square = Annotation::Square.new
        text = Annotation::Text.new
        link = Annotation::Link.new
        file = Annotation::FileAttachment.new
        screen = Annotation::Screen.new
        sound = Annotation::Sound.new
        pushbutton = Annotation::Widget::PushButton.new
        checkbox = Annotation::Widget::CheckBox.new
        radio = Annotation::Widget::Radio.new
        edit = Annotation::Widget::Text.new
        combo = Annotation::Widget::ComboBox.new
        list = Annotation::Widget::ListBox.new
        sig = Annotation::Widget::Signature.new

        all_annots = [
            circle, square, text, link,
            file, screen, sound, pushbutton,
            checkbox, radio, edit, combo,
            list, sig
        ]

        @target.append_page @page

        @page.add_annotation circle
        @page.add_annotation square
        @page.add_annotation text
        @page.add_annotation link
        @page.add_annotation file
        @page.add_annotation screen
        @page.add_annotation sound
        @page.add_annotation pushbutton
        @page.add_annotation checkbox
        @page.add_annotation radio
        @page.add_annotation edit
        @page.add_annotation combo
        @page.add_annotation list
        @page.add_annotation sig

        @page.each_annotation do |annotation|
            assert_kind_of Annotation, annotation

            assert all_annots.include?(annotation)
        end

        assert_equal @page.annotations.size, all_annots.size

        @target.save(@output)
    end

    def test_annotation_actions
        screen = Annotation::Screen.new

        @page.add_annotation screen

        screen.onMouseOver @action
        screen.onMouseOut @action
        screen.onMouseDown @action
        screen.onMouseUp @action
        screen.onFocus @action
        screen.onBlur @action
        screen.onPageOpen @action
        screen.onPageClose @action
        screen.onPageVisible @action
        screen.onPageInvisible @action

        assert_equal screen.AA.E, @action
        assert_equal screen.AA.X, @action
        assert_equal screen.AA.D, @action
        assert_equal screen.AA.U, @action
        assert_equal screen.AA.Fo, @action
        assert_equal screen.AA.Bl, @action
        assert_equal screen.AA.PO, @action
        assert_equal screen.AA.PC, @action
        assert_equal screen.AA.PV, @action
        assert_equal screen.AA.PI, @action
    end
end
