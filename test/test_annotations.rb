require 'minitest/autorun'
require 'stringio'

class TestAnnotations < Minitest::Test
    def setup
        @target = PDF.new
        @page = Page.new
        @action = Action::JavaScript["app.alert(null);"]
        @output = StringIO.new

        @types = [ 
            Annotation::Circle, Annotation::Square,
            Annotation::Text, Annotation::Link,
            Annotation::FileAttachment, Annotation::Screen,
            Annotation::Sound, Annotation::Widget::CheckBox,
            Annotation::Widget::Radio, Annotation::Widget::Text,
            Annotation::Widget::ComboBox, Annotation::Widget::ListBox,
            Annotation::Widget::Signature
        ]
    end

    def test_annotations
        @target.append_page @page

        annotations = @types.map(&:new)
        annotations.each do |annotation|
            @page.add_annotation(annotation)
        end

        @page.each_annotation do |annotation|
            assert_kind_of Annotation, annotation

            assert annotations.include?(annotation)
        end

        assert_equal @page.annotations.size, annotations.size

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
