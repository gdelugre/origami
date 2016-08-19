require 'minitest/autorun'
require 'stringio'

class TestPages < Minitest::Test
    def setup
        @target = PDF.new
        @output = StringIO.new
    end

    def test_append_page
        p1, p2, p3 = Page.new, Page.new, Page.new

        @target.append_page p1
        @target.append_page p2
        @target.append_page p3

        assert_equal @target.pages.count, 3

        assert_equal @target.get_page(1), p1
        assert_equal @target.get_page(2), p2
        assert_equal @target.get_page(3), p3

        assert_equal @target.Catalog.Pages, p1.Parent
        assert_equal @target.Catalog.Pages, p2.Parent
        assert_equal @target.Catalog.Pages, p3.Parent

        @target.save(@output)

        assert_equal @target.Catalog.Pages.Count, 3
    end
end
