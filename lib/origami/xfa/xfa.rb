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

require 'rexml/element'

module Origami

    module XFA
        class XFAError < Error #:nodoc:
        end

        module ClassMethods

            def xfa_attribute(name)
                # Attribute getter.
                attr_getter = "attr_#{name}"
                remove_method(attr_getter) rescue NameError
                define_method(attr_getter) do
                    self.attributes[name.to_s]
                end

                # Attribute setter.
                attr_setter = "attr_#{name}="
                remove_method(attr_setter) rescue NameError
                define_method(attr_setter) do |value|
                    self.attributes[name.to_s] = value
                end
            end

            def xfa_node(name, type, _range = (0..Float::INFINITY))

                adder = "add_#{name}"
                remove_method(adder) rescue NameError
                define_method(adder) do |*attr|
                    elt = self.add_element(type.new)

                    unless attr.empty?
                        attr.first.each do |k,v|
                            elt.attributes[k.to_s] = v
                        end
                    end

                    elt
                end
            end

            def mime_type(type)
                define_method("mime_type") { return type }
            end
        end

        def self.included(receiver)
            receiver.extend(ClassMethods)
        end

        class Element < REXML::Element
            include XFA

            #
            # A permission flag for allowing or blocking attempted changes to the element.
            # 0 - Allow changes to properties and content.
            # 1 - Block changes to properties and content.
            #
            module Lockable
                def lock!
                    self.attr_lock = 1
                end

                def unlock!
                    self.attr_lock = 0
                end

                def locked?
                    self.attr_lock == 1
                end

                def self.included(receiver)
                    receiver.xfa_attribute "lock"
                end
            end

            #
            # An attribute to hold human-readable metadata.
            #
            module Descriptive
                def self.included(receiver)
                    receiver.xfa_attribute "desc"
                end
            end

            #
            # A unique identifier that may be used to identify this element as a target.
            #
            module Referencable
                def self.included?(receiver)
                    receiver.xfa_attribute "id"
                end
            end

            #
            # At template load time, invokes another object in the same document as a prototype for this object.
            #
            module Prototypable
                def self.included?(receiver)
                    receiver.xfa_attribute "use"
                    receiver.xfa_attribute "usehref"
                end
            end

            #
            # An identifier that may be used to identify this element in script expressions.
            #
            module Namable
                def self.included?(receiver)
                    receiver.xfa_attribute "name"
                end
            end
        end

        class TemplateElement < Element
            include Referencable
            include Prototypable
        end

        class NamedTemplateElement < TemplateElement
            include Namable
        end
    end
end
