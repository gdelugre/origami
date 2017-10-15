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

module Origami

    module XFA
        class ConnectionElement < Element
            xfa_attribute 'dataDescription'
            xfa_attribute 'name'
        end
    end

    module XDP

        module Packet

            #
            # The _connectionSet_ packet describes the connections used to initiate or conduct web services.
            #
            class ConnectionSet < XFA::Element
                mime_type 'text/xml'

                def initialize
                    super("connectionSet")

                    add_attribute 'xmlns', 'http://www.xfa.org/schema/xfa-connection-set/2.8/'
                end

                class EffectiveInputPolicy < XFA::NamedTemplateElement
                    def initialize
                        super('effectiveInputPolicy')
                    end
                end

                class EffectiveOutputPolicy < XFA::NamedTemplateElement
                    def initialize
                        super('effectiveOutputPolicy')
                    end
                end

                class Operation < XFA::NamedTemplateElement
                    xfa_attribute 'input'
                    xfa_attribute 'output'

                    def initialize(name = "")
                        super('operation')

                        self.text = name
                    end
                end

                class SOAPAction < XFA::NamedTemplateElement
                    def initialize(uri = "")
                        super('soapAction')

                        self.text = uri
                    end
                end

                class SOAPAddress < XFA::NamedTemplateElement
                    def initialize(addr = "")
                        super('soapAddress')

                        self.text = addr
                    end
                end

                class WSDLAddress < XFA::NamedTemplateElement
                    def initialize(addr = "")
                        super('wsdlAddress')

                        self.text = addr
                    end
                end

                class WSDLConnection < XFA::ConnectionElement
                    xfa_node 'effectiveInputPolicy', ConnectionSet::EffectiveInputPolicy, 0..1
                    xfa_node 'effectiveOutputPolicy', ConnectionSet::EffectiveOutputPolicy, 0..1
                    xfa_node 'operation', ConnectionSet::Operation, 0..1
                    xfa_node 'soapAction', ConnectionSet::SOAPAction, 0..1
                    xfa_node 'soapAddress', ConnectionSet::SOAPAddress, 0..1
                    xfa_node 'wsdlAddress', ConnectionSet::WSDLAddress, 0..1

                    def initialize
                        super('wsdlConnection')
                    end
                end

                class URI < XFA::NamedTemplateElement
                    def initialize(uri = "")
                        super('uri')

                        self.text = uri
                    end
                end

                class RootElement < XFA::NamedTemplateElement
                    def initialize(root = '')
                        super('rootElement')

                        self.text = root
                    end
                end

                class XSDConnection < XFA::ConnectionElement
                    xfa_node 'rootElement', ConnectionSet::RootElement, 0..1
                    xfa_node 'uri', ConnectionSet::URI, 0..1

                    def initialize
                        super('xsdConnection')
                    end
                end

                class XMLConnection < XFA::ConnectionElement
                    xfa_node 'uri', ConnectionSet::URI, 0..1

                    def initialize
                        super('xmlConnection')
                    end
                end

                xfa_node 'wsdlConnection', ConnectionSet::WSDLConnection
                xfa_node 'xmlConnection', ConnectionSet::XMLConnection
                xfa_node 'xsdConnection', ConnectionSet::XSDConnection
            end

        end
    end
end
