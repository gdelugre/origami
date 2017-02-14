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

require 'rexml/document'

module Origami

    module XDP

        class XDP < XFA::Element
            xfa_attribute 'uuid'
            xfa_attribute 'timeStamp'

            xfa_node 'config', Origami::XDP::Packet::Config, 0..1
            xfa_node 'connectionSet', Origami::XDP::Packet::ConnectionSet, 0..1
            xfa_node 'datasets', Origami::XDP::Packet::Datasets, 0..1
            xfa_node 'localeSet', Origami::XDP::Packet::LocaleSet, 0..1
            xfa_node 'pdf', Origami::XDP::Packet::PDF, 0..1
            xfa_node 'sourceSet', Origami::XDP::Packet::SourceSet, 0..1
            xfa_node 'styleSheet', Origami::XDP::Packet::StyleSheet, 0..1
            xfa_node 'template', Origami::XDP::Packet::Template, 0..1
            xfa_node 'xdc', Origami::XDP::Packet::XDC, 0..1
            xfa_node 'xfdf', Origami::XDP::Packet::XFDF, 0..1
            xfa_node 'xmpmeta', Origami::XDP::Packet::XMPMeta, 0..1

            def initialize
                super('xdp:xdp')

                add_attribute 'xmlns:xdp', 'http://ns.adobe.com/xdp/'
            end
        end

        class Package < REXML::Document
            def initialize(package = nil)
                super(package || REXML::XMLDecl.new.to_s)

                add_element Origami::XDP::XDP.new if package.nil?
            end
        end
    end

end
