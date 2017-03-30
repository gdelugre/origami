require 'minitest/autorun'

class TestForms < Minitest::Test
    def setup
        @target = PDF.new
        @target.append_page
    end

    def test_create_acroform
        fields = [
            Annotation::Widget::Text.new.set_name('text'),
            Annotation::Widget::PushButton.new.set_name('button')
        ]

        @target.create_form(*fields)

        assert @target.form?
        assert_kind_of InteractiveForm, @target.Catalog.AcroForm
        assert_equal @target.fields.length, fields.length

        @target.each_field do |field|
            assert_kind_of Field, field
            assert %w{text button}.include?(field.name) 
        end

        assert_nil @target.get_field('not_existent_field')
        assert_kind_of Field, @target.get_field('button')
        assert_kind_of Field, @target.get_field('text')
    end
end
