=begin

    This file is part of Origami, PDF manipulation framework for Ruby
    Copyright (C) 2017	Guillaume Delugré.

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

require 'set'

module Origami

    #
    # Module for maintaining internal caches of objects for fast lookup.
    #
    module ObjectCache
        attr_reader :strings_cache, :names_cache, :xref_cache

        def initialize(*args)
            super(*args)

            init_caches
        end

        def rebuild_caches
            self.each do |*items|
                items.each do |object|
                    object.rebuild_caches if object.is_a?(CompoundObject)
                    cache_object(object)
                end
            end
        end

        private

        def init_caches
            @strings_cache = Set.new
            @names_cache = Set.new
            @xref_cache = {}
        end

        def cache_object(object)
            case object
            when String then cache_string(object)
            when Name then cache_name(object)
            when Reference then cache_reference(object)
            when CompoundObject then cache_compound(object)
            end

            object
        end

        def cache_compound(object)
            @strings_cache.merge(object.strings_cache)
            @names_cache.merge(object.names_cache)
            @xref_cache.update(object.xref_cache) do |_, cache1, cache2|
                cache1.concat(cache2)
            end

            object.strings_cache.clear
            object.names_cache.clear
            object.xref_cache.clear
        end

        def cache_string(str)
            @strings_cache.add(str)
        end

        def cache_name(name)
            @names_cache.add(name)
        end

        def cache_reference(ref)
            @xref_cache[ref] ||= []
            @xref_cache[ref].push(self)
        end
    end

    #
    # Module for objects containing other objects.
    #
    module CompoundObject
        include Origami::Object
        include ObjectCache
        using TypeConversion

        #
        # Returns true if the item is present in the compound object.
        #
        def include?(item)
            super(item.to_o)
        end

        #
        # Removes the item from the compound object if present.
        #
        def delete(item)
            obj = super(item.to_o)
            unlink_object(obj) unless obj.nil?
        end

        #
        # Creates a deep copy of the compound object.
        # This method can be quite expensive as nested objects are copied too.
        #
        def copy
            obj = self.update_values(&:copy)

            transfer_attributes(obj)
        end

        #
        # Returns a new compound object with updated values based on the provided block.
        #
        def update_values(&b)
            return enum_for(__method__) unless block_given?
            return self.class.new self.transform_values(&b) if self.respond_to?(:transform_values)
            return self.class.new self.map(&b) if self.respond_to?(:map)

            raise NotImplementedError, "This object does not implement this method"
        end

        #
        # Modifies the compound object's values based on the provided block.
        #
        def update_values!(&b)
            return enum_for(__method__) unless block_given?
            return self.transform_values!(&b) if self.respond_to?(:transform_values!)
            return self.map!(&b) if self.respond_to?(:map!)

            raise NotImplementedError, "This object does not implement this method"
        end

        private

        def link_object(item)
            obj = item.to_o
            obj.parent = self unless obj.indirect?

            cache_object(obj)
        end

        def unlink_object(obj)
            obj.parent = nil 
            obj
        end
    end

end
