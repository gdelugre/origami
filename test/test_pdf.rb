require 'minitest/autorun'

$:.unshift File.join(__dir__, "..", "lib")
require 'origami'
include Origami

require_relative 'test_native_types'
require_relative 'test_pdf_parse'
require_relative 'test_pdf_parse_lazy'
require_relative 'test_pdf_create'
require_relative 'test_streams'
require_relative 'test_pdf_encrypt'
require_relative 'test_pdf_sign'
require_relative 'test_pdf_attachment'
require_relative 'test_pages'
require_relative 'test_actions'
require_relative 'test_annotations'
require_relative 'test_forms'
require_relative 'test_xrefs'
require_relative 'test_object_tree'
