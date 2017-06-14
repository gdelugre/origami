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

    class PDF

        class LinearizationError < Error #:nodoc:
        end

        #
        # Returns whether the current document is linearized.
        #
        def linearized?
            begin
                first_obj = @revisions.first.objects.min_by{|obj| obj.file_offset}
            rescue
                return false
            end

            @revisions.size > 1 and first_obj.is_a?(Dictionary) and first_obj.has_key? :Linearized
        end

        #
        # Tries to delinearize the document if it has been linearized.
        # This operation is xrefs destructive, should be fixed in the future to merge tables.
        #
        def delinearize!
            raise LinearizationError, 'Not a linearized document' unless self.linearized?

            #
            # Saves the first trailer.
            #
            prev_trailer = @revisions.first.trailer

            linear_dict = @revisions.first.objects.min_by{|obj| obj.file_offset}

            #
            # Removes hint streams used by linearization.
            #
            delete_hint_streams(linear_dict)

            #
            # Update the trailer.
            #
            last_trailer = (@revisions.last.trailer ||= Trailer.new)
            last_trailer.dictionary ||= Dictionary.new

            if prev_trailer.dictionary?
                last_trailer.dictionary =
                    last_trailer.dictionary.merge(prev_trailer.dictionary)
            else
                xrefstm = @revisions.last.xrefstm
                raise LinearizationError,
                        'Cannot find trailer info while delinearizing document' unless xrefstm.is_a?(XRefStream)

                last_trailer.dictionary[:Root] = xrefstm[:Root]
                last_trailer.dictionary[:Encrypt] = xrefstm[:Encrypt]
                last_trailer.dictionary[:Info] = xrefstm[:Info]
                last_trailer.dictionary[:ID] = xrefstm[:ID]
            end

            #
            # Remove all xrefs.
            # Fix: Should be merged instead.
            #
            remove_xrefs

            #
            # Remove the linearization revision.
            #
            @revisions.first.body.delete(linear_dict.reference)
            @revisions.last.body.merge! @revisions.first.body

            remove_revision(0)

            self
        end

        private

        #
        # Strip the document from Hint streams given a linearization dictionary.
        #
        def delete_hint_streams(linearization_dict)
            hints = linearization_dict[:H]
            return unless hints.is_a?(Array)

            hints.each_slice(2) do |offset, _length|
                next unless offset.is_a?(Integer)

                stream = get_object_by_offset(offset)
                delete_object(stream.reference) if stream.is_a?(Stream)
            end
        end
    end

    #
    # Class representing a linearization dictionary.
    #
    class Linearization < Dictionary
        include StandardObject

        field   :Linearized,   :Type => Real, :Default => 1.0, :Required => true
        field   :L,            :Type => Integer, :Required => true
        field   :H,            :Type => Array.of(Integer), :Required => true
        field   :O,            :Type => Integer, :Required => true
        field   :E,            :Type => Integer, :Required => true
        field   :N,            :Type => Integer, :Required => true
        field   :T,            :Type => Integer, :Required => true
        field   :P,            :Type => Integer, :Default => 0

        def initialize(hash = {}, parser = nil)
            super(hash, parser)

            set_indirect(true)
        end
    end

   class InvalidHintTableError < Error #:nodoc:
   end

    module HintTable
        module ClassMethods
            def header_item_size(number, size)
                @header_items_size[number] = size
            end

            def get_header_item_size(number)
                @header_items_size[number]
            end

            def entry_item_size(number, size)
                @entry_items_size[number] = size
            end

            def get_entry_item_size(number)
                @entry_items_size[number]
            end

            def nb_header_items
                @header_items_size.size
            end

            def nb_entry_items
                @entry_items_size.size
            end
        end

        def self.included(receiver)
            receiver.instance_variable_set(:@header_items_size, {})
            receiver.instance_variable_set(:@entry_items_size, {})
            receiver.extend(ClassMethods)
        end

        attr_accessor :header_items
        attr_accessor :entries

        def initialize
            @header_items = {}
            @entries = []
        end

        def to_s
            data = ""

            nitems = self.class.nb_header_items
            for no in (1..nitems)
                unless @header_items.include?(no)
                    raise InvalidHintTableError, "Missing item #{no} in header section of #{self.class}"
                end

                value = @header_items[no]
                item_size = self.class.get_header_item_size(no)

                item_size = ((item_size + 7) >> 3) << 3
                item_data = value.to_s(2)
                item_data = "0" * (item_size - item_data.size) + item_data

                data << [ item_data ].pack("B*")
            end

            nitems = self.class.nb_entry_items
            @entries.each_with_index do |entry, i|
                for no in (1..nitems)
                    unless entry.include?(no)
                        raise InvalidHintTableError, "Missing item #{no} in entry #{i} of #{self.class}"
                    end

                    value = entry[no]
                    item_size = self.class.get_entry_item_size(no)

                    item_size = ((item_size + 7) >> 3) << 3
                    item_data = value.to_s(2)
                    item_data = "0" * (item_size - item_data.size) + item_data

                    data << [ item_data ].pack("B*")
                end
            end

            data
        end

        class PageOffsetTable
            include HintTable

            header_item_size  1,  32
            header_item_size  2,  32
            header_item_size  3,  16
            header_item_size  4,  32
            header_item_size  5,  16
            header_item_size  6,  32
            header_item_size  7,  16
            header_item_size  8,  32
            header_item_size  9,  16
            header_item_size  10,  16
            header_item_size  11,  16
            header_item_size  12,  16
            header_item_size  13,  16

            entry_item_size   1,  16
            entry_item_size   2,  16
            entry_item_size   3,  16
            entry_item_size   4,  16
            entry_item_size   5,  16
            entry_item_size   6,  16
            entry_item_size   7,  16
        end

        class SharedObjectTable
            include HintTable

            header_item_size  1,  32
            header_item_size  2,  32
            header_item_size  3,  32
            header_item_size  4,  32
            header_item_size  5,  16
            header_item_size  6,  32
            header_item_size  7,  16

            entry_item_size   1,  16
            entry_item_size   2,  1
            entry_item_size   3,  128
            entry_item_size   4,  16
        end
    end

    class InvalidHintStreamObjectError < InvalidStreamObjectError #:nodoc:
    end

    class HintStream < Stream
        attr_accessor :page_offset_table
        attr_accessor :shared_objects_table
        attr_accessor :thumbnails_table
        attr_accessor :outlines_table
        attr_accessor :threads_table
        attr_accessor :named_destinations_table
        attr_accessor :interactive_forms_table
        attr_accessor :information_dictionary_table
        attr_accessor :logical_structure_table
        attr_accessor :page_labels_table
        attr_accessor :renditions_table
        attr_accessor :embedded_files_table

        field   :S,             :Type => Integer, :Required => true # Shared objects
        field   :T,             :Type => Integer  # Thumbnails
        field   :O,             :Type => Integer  # Outlines
        field   :A,             :Type => Integer  # Threads
        field   :E,             :Type => Integer  # Named destinations
        field   :V,             :Type => Integer  # Interactive forms
        field   :I,             :Type => Integer  # Information dictionary
        field   :C,             :Type => Integer  # Logical structure
        field   :L,             :Type => Integer  # Page labels
        field   :R,             :Type => Integer  # Renditions
        field   :B,             :Type => Integer  # Embedded files

        def pre_build
            if @page_offset_table.nil?
                raise InvalidHintStreamObjectError, "No page offset hint table"
            end

            if @shared_objects_table.nil?
                raise InvalidHintStreamObjectError, "No shared objects hint table"
            end

            @data = ""
            save_table(@page_offset_table)
            save_table(@shared_objects_table,         :S)
            save_table(@thumbnails_table,             :T)
            save_table(@outlines_table,               :O)
            save_table(@threads_table,                :A)
            save_table(@named_destinations_table,     :E)
            save_table(@interactive_forms_table,      :V)
            save_table(@information_dictionary_table, :I)
            save_table(@logical_structure_table,      :C)
            save_table(@page_labels_table,            :L)
            save_table(@renditions_table,             :R)
            save_table(@embedded_files_table,         :B)

            super
        end

        private

        def save_table(table, name = nil)
            unless table.nil?
                self[name] = @data.size if name
                @data << table.to_s
            end
        end
    end

end
