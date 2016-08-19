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

        #
        # Exports the document to a dot Graphiz file.
        # _filename_:: The path where to save the file.
        #
        def export_to_graph(path)

            appearance = -> (object) do
                label = object.type.to_s
                case object
                when Catalog
                    fontcolor = "red"
                    color = "mistyrose"
                    shape = "ellipse"
                when Name, Number
                    label = object.value
                    fontcolor = "brown"
                    color = "lightgoldenrodyellow"
                    shape = "polygon"
                when String
                    label = object.value if (object.ascii_only? and object.length <= 50)
                    fontcolor = "red"
                    color = "white"
                    shape = "polygon"
                when Array
                    fontcolor = "darkgreen"
                    color = "lightcyan"
                    shape = "ellipse"
                else
                  fontcolor = "blue"
                  color = "aliceblue"
                  shape = "ellipse"
                end

                { label: label, fontcolor: fontcolor, color: color, shape: shape }
            end

            add_edges = -> (fd, object) do
                if object.is_a?(Array) or object.is_a?(ObjectStream)
                    object.each do |subobj|
                        fd << "\t#{object.object_id} -> #{subobj.solve.object_id}\n"
                    end

                elsif object.is_a?(Dictionary)
                    object.each_pair do |name, subobj|
                        fd << "\t#{object.object_id} -> #{subobj.solve.object_id} "
                        fd << "[label=\"#{name.value}\",fontsize=9];\n"
                    end
                end

                if object.is_a?(Stream)
                    object.dictionary.each_pair do |key, value|
                        fd << "\t#{object.object_id} -> #{value.solve.object_id} "
                        fd << "[label=\"#{key.value}\",fontsize=9];\n"
                    end
                end
            end

            graph_name = "PDF" if graph_name.nil? or graph_name.empty?
            fd = File.open(path, "w")

            begin
                fd << "digraph #{graph_name} {\n\n"

                objects = self.objects(include_keys: false).find_all{ |obj| not obj.is_a?(Reference) }

                objects.each do |object|
                    attr = appearance[object]

                    fd << "\t#{object.object_id} "
                    fd << "[label=\"#{attr[:label]}\",shape=#{attr[:shape]},color=#{attr[:color]},style=filled,fontcolor=#{attr[:fontcolor]},fontsize=16];\n"

                    if object.is_a?(Stream)
                        object.dictionary.each do |value|
                            unless value.is_a?(Reference)
                                attr = appearance[value]
                                fd << "\t#{value.object_id} "
                                fd << "[label=\"#{attr[:label]}\",shape=#{attr[:shape]},color=#{attr[:color]},style=filled,fontcolor=#{attr[:fontcolor]},fontsize=16];\n"
                            end
                        end
                    end

                    add_edges.call(fd, object)
                end

                fd << "\n}"
            ensure
                fd.close
            end
        end

        #
        # Exports the document to a GraphML file.
        # _filename_:: The path where to save the file.
        #
        def export_to_graphml(path)
            require 'rexml/document'

            declare_node = -> (id, attr) do
                <<-XML
                <node id="#{id}">
                    <data key="d0">
                        <y:ShapeNode>
                            <y:NodeLabel>#{attr[:label]}</y:NodeLabel>
                        </y:ShapeNode>
                    </data>
                </node>
                XML
            end

            declare_edge = -> (id, src, dest, label = nil) do
                <<-XML
                <edge id="#{id}" source="#{src}" target="#{dest}">
                    <data key="d1">
                        <y:PolyLineEdge>
                            <y:LineStyle type="line" width="1.0" color="#000000"/>
                            <y:Arrows source="none" target="standard"/>
                            <y:EdgeLabel>#{label.to_s}</y:EdgeLabel>
                        </y:PolyLineEdge>
                    </data>
                </edge>
                XML
            end

            appearance = -> (object) do
                label = object.type.to_s
                case object
                when Catalog
                    fontcolor = "red"
                    color = "mistyrose"
                    shape = "doublecircle"
                when Name, Number
                    label = object.value
                    fontcolor = "orange"
                    color = "lightgoldenrodyellow"
                    shape = "polygon"
                when String
                    label = object.value if (object.ascii_only? and object.length <= 50)
                    fontcolor = "red"
                    color = "white"
                    shape = "polygon"
                when Array
                    fontcolor = "green"
                    color = "lightcyan"
                    shape = "ellipse"
                else
                  fontcolor = "blue"
                  color = "aliceblue"
                  shape = "ellipse"
                end

                { label: label, fontcolor: fontcolor, color: color, shape: shape }
            end

            add_edges = -> (xml, object, id) do
                if object.is_a?(Array) or object.is_a?(ObjectStream)
                    object.each do |subobj|
                        xml << declare_edge["e#{id}", "n#{object.object_id}", "n#{subobj.solve.object_id}"]
                        id = id + 1
                    end

                elsif object.is_a?(Dictionary)
                    object.each_pair do |name, subobj|
                        xml << declare_edge["e#{id}", "n#{object.object_id}", "n#{subobj.solve.object_id}",
                                           name.value]
                        id = id + 1
                    end
                end

                if object.is_a?(Stream)
                    object.dictionary.each_pair do |key, value|
                        xml << declare_edge["e#{id}", "n#{object.object_id}", "n#{value.object_id}", key.value]
                        id = id + 1
                    end
                end

                id
            end

            graph_name = "PDF" if graph_name.nil? or graph_name.empty?

            edge_nb = 1
            xml = <<-XML
                <?xml version="1.0" encoding="UTF-8"?>
                <graphml xmlns="http://graphml.graphdrawing.org/xmlns/graphml"
                         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                         xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns/graphml
                                             http://www.yworks.com/xml/schema/graphml/1.0/ygraphml.xsd"
                         xmlns:y="http://www.yworks.com/xml/graphml">
                    <key id="d0" for="node" yfiles.type="nodegraphics"/>
                    <key id="d1" for="edge" yfiles.type="edgegraphics"/>
                    <graph id="#{graph_name}" edgedefault="directed">
            XML

            objects = self.objects(include_keys: false).find_all{ |obj| not obj.is_a?(Reference) }

            objects.each do |object|
                xml << declare_node["n#{object.object_id}", appearance[object]]

                if object.is_a?(Stream)
                    object.dictionary.each do |value|
                        unless value.is_a?(Reference)
                            xml << declare_node[value.object_id, appearance[value]]
                        end
                    end
                end

                edge_nb = add_edges[xml, object, edge_nb]
            end

            xml << '</graph>' << "\n"
            xml << '</graphml>'

            doc = REXML::Document.new(xml)
            formatter = REXML::Formatters::Pretty.new(4)
            formatter.compact = true

            File.open(path, "w") do |fd|
                formatter.write(doc, fd)
            end
        end
    end

end
