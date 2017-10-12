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

        assert_raises(IndexError) { @target.get_page(0) }
        assert_raises(IndexError) { @target.get_page(4) }

        assert_equal @target.Catalog.Pages, p1.Parent
        assert_equal @target.Catalog.Pages, p2.Parent
        assert_equal @target.Catalog.Pages, p3.Parent

        @target.save(@output)

        assert_equal @target.Catalog.Pages.Count, 3
        assert_equal @target.pages, [p1, p2, p3]
        assert_equal @target.each_page.to_a, [p1, p2, p3]
    end

    def test_insert_page
        pages = Array.new(10) { Page.new }

        pages.each_with_index do |page, index|
            @target.insert_page(index + 1, page)
        end

        assert_equal @target.pages, pages

        new_page = Page.new
        @target.insert_page(1, new_page)
        assert_equal @target.get_page(1), new_page

        assert_raises(IndexError) { @target.insert_page(0, Page.new) }
        assert_raises(IndexError) { @target.insert_page(1000, Page.new) }
    end

    def test_example_write_page
        @target.append_page
        @target.pages.first.write 'Hello, world!', size: 30
        @target.save(@output)
        assert_equal @target.Catalog.Pages.Count, 1
    end
end
