require 'minitest/autorun'

class TestActions < MiniTest::Test
    def setup
        @target = PDF.new
        @page = Page.new
        @action = Action::JavaScript "app.alert(null);"
    end

    def test_pdf_actions
        @target.onDocumentOpen @action
        @target.onDocumentClose @action
        @target.onDocumentPrint @action

        assert_equal @target.Catalog.OpenAction, @action
        assert_equal @target.Catalog.AA.WC, @action
        assert_equal @target.Catalog.AA.WP, @action
    end

    def test_page_actions
        @page.onOpen @action
        @page.onClose @action

        assert_equal @page.AA.O, @action
        assert_equal @page.AA.C, @action
    end
end
