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

require 'rexml/document'

module Origami

    class XFAStream < Stream
        # TODO
    end

    class PDF
        def create_xfa_form(xdp, *fields)
            acroform = create_form(*fields)
            acroform.XFA = XFAStream.new(xdp, :Filter => :FlateDecode)

            acroform
        end

        def xfa_form?
            self.form? and self.Catalog.AcroForm.key?(:XFA)
        end
    end

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
                    self.attributes[names.to_s] = value
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
        end
    end

    module XDP

        module Packet
            #
            # This packet encloses the configuration settings.
            #
            class Config < XFA::Element
                mime_type 'text/xml'

                def initialize
                    super("config")

                    add_attribute 'xmlns:xfa', 'http://www.xfa.org/schema/xci/3.0/'
                end

                class URI < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(uri = "")
                        super('uri')

                        self.text = uri
                    end
                end

                class Debug < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('debug')
                    end
                end

                class AdjustData < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(coercion = "0")
                        super('adjustData')

                        self.text = coercion
                    end
                end

                class Attributes < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    PRESERVE = "preserve"
                    DELEGATE = "delegate"
                    IGNORE = "ignore"

                    def initialize(attr = PRESERVE)
                        super('attributes')

                        self.text = attr
                    end
                end

                class IncrementalLoad < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    NONE = "none"
                    FORWARDONLY = "forwardOnly"

                    def initialize(incload = NONE)
                        super('incrementalLoad')

                        self.text = incload
                    end
                end

                class Locale < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(locale = "")
                        super('locale')

                        self.text = locale
                    end
                end

                class LocaleSet < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(uri = "")
                        super('localeSet')

                        self.text = uri
                    end
                end

                class OutputXSL < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('outputXSL')
                    end
                end

                class Range < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(range = "")
                        super('range')

                        self.text = range
                    end
                end

                class Record < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(record = "")
                        super('record')

                        self.text = record
                    end
                end

                class StartNode < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(somexpr = "")
                        super('startNode')

                        self.text = somexpr
                    end
                end

                class Window < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(win = "0")
                        super('window')

                        self.text = win
                    end
                end

                class XSL < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'debug', Config::Debug, 0..1
                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('xsl')
                    end
                end

                class ExcludeNS < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(ns = "")
                        super('excludeNS')

                        self.text = ns
                    end
                end

                class GroupParent < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(parentname = "")
                        super('groupParent')

                        self.text = parentname
                    end
                end

                class IfEmpty < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    DATAVALUE = "dataValue"
                    DATAGROUP = "dataGroup"
                    IGNORE = "ignore"
                    REMOVE = "remove"

                    def initialize(default = DATAVALUE)
                        super('ifEmpty')

                        self.text = default
                    end
                end

                class NameAttr < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(name)
                        super('nameAttr')

                        self.text = name
                    end
                end

                class Picture < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(clause = "")
                        super('picture')

                        self.text = clause
                    end
                end

                class Presence < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    PRESERVE = "preserve"
                    DISSOLVE = "dissolve"
                    DISSOLVESTRUCTURE = "dissolveStructure"
                    IGNORE = "ignore"
                    REMOVE = "remove"

                    def initialize(action = PRESERVE)
                        super('presence')

                        self.text = action
                    end
                end

                class Rename < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(nodename = "")
                        super('rename')

                        self.text = nodename
                    end
                end

                class Whitespace < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    PRESERVE = "preserve"
                    LTRIM = "ltrim"
                    NORMALIZE = "normalize"
                    RTRIM = "rtrim"
                    TRIM = "trim"

                    def initialize(action = PRESERVE)
                        super('whitespace')

                        self.text = action
                    end
                end

                class Transform < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'
                    xfa_attribute 'ref'

                    xfa_node 'groupParent', Config::GroupParent, 0..1
                    xfa_node 'ifEmpty', Config::IfEmpty, 0..1
                    xfa_node 'nameAttr', Config::NameAttr, 0..1
                    xfa_node 'picture', Config::Picture, 0..1
                    xfa_node 'presence', Config::Presence, 0..1
                    xfa_node 'rename', Config::Rename, 0..1
                    xfa_node 'whitespace', Config::Whitespace, 0..1
                end

                class Data < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'adjustData', Config::AdjustData, 0..1
                    xfa_node 'attributes', Config::Attributes, 0..1
                    xfa_node 'incrementalLoad', Config::IncrementalLoad, 0..1
                    xfa_node 'outputXSL', Config::OutputXSL, 0..1
                    xfa_node 'range', Config::Range, 0..1
                    xfa_node 'record', Config::Record, 0..1
                    xfa_node 'startNode', Config::StartNode, 0..1
                    xfa_node 'uri', Config::URI, 0..1
                    xfa_node 'window', Config::Window, 0..1
                    xfa_node 'xsl', Config::XSL, 0..1

                    xfa_node 'excludeNS', Config::ExcludeNS
                    xfa_node 'transform', Config::Transform

                    def initialize
                        super('data')
                    end
                end

                class Severity < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    IGNORE = "ignore"
                    ERROR = "error"
                    INFORMATION = "information"
                    TRACE = "trace"
                    WARNING = "warning"

                    def initialize(level = IGNORE)
                        super('severity')

                        self.text = level
                    end
                end

                class MsgId < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(uid = "1")
                        super('msgId')

                        self.text = uid
                    end
                end

                class Message < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'msgId', Config::MsgId, 0..1
                    xfa_node 'severity', Config::Severity, 0..1

                    def initialize
                        super('message')
                    end
                end

                class Messaging < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'message', Config::Message

                    def initialize
                        super('messaging')
                    end
                end

                class SuppressBanner < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    ALLOWED = "0"
                    DENIED = "1"

                    def initialize(display = ALLOWED)
                        super('suppressBanner')

                        self.text = display
                    end
                end

                class Base < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(uri = "")
                        super('base')

                        self.text = uri
                    end
                end

                class Relevant < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(token = "")
                        super('relevant')

                        self.text = token
                    end
                end

                class StartPage < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    def initialize(pagenum = "0")
                        super('startPage')

                        self.text = pagenum
                    end
                end

                class Template < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'base', Config::Base, 0..1
                    xfa_node 'relevant', Config::Relevant, 0..1
                    xfa_node 'startPage', Config::StartPage, 0..1
                    xfa_node 'uri', Config::URI, 0..1
                    xfa_node 'xsl', Config::XSL, 0..1

                    def initialize
                        super('template')
                    end
                end

                class ValidationMessaging < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    ALL_INDIVIDUALLY = "allMessagesIndividually"
                    ALL_TOGETHER = "allMessagesTogether"
                    FIRST_ONLY = "firstMessageOnly"
                    NONE = "noMessages"

                    def initialize(validate = ALL_INDIVIDUALLY)
                        super('validationMessaging')

                        self.text = validate
                    end
                end

                class VersionControl < XFA::Element
                    xfa_attribute 'lock'
                    xfa_attribute 'outputBelow'
                    xfa_attribute 'sourceAbove'
                    xfa_attribute 'sourceBelow'

                    def initialize
                        super('versionControl')
                    end
                end

                class Mode < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    APPEND = "append"
                    OVERWRITE = "overwrite"

                    def initialize(mode = APPEND)
                        super('mode')

                        self.text = mode
                    end
                end

                class Threshold < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    TRACE = "trace"
                    ERROR = "error"
                    INFORMATION = "information"
                    WARN = "warn"

                    def initialize(threshold = TRACE)
                        super('threshold')

                        self.text = threshold
                    end
                end

                class To < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    NULL = "null"
                    MEMORY = "memory"
                    STD_ERR = "stderr"
                    STD_OUT = "stdout"
                    SYSTEM = "system"
                    URI = "uri"

                    def initialize(dest = NULL)
                        super('to')

                        self.text = dest
                    end
                end

                class Log < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'mode', Config::Mode, 0..1
                    xfa_node 'threshold', Config::Threshold, 0..1
                    xfa_node 'to', Config::To, 0..1
                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('log')
                    end
                end

                class Common < XFA::Element
                    xfa_attribute 'desc'
                    xfa_attribute 'lock'

                    xfa_node 'data', Config::Data, 0..1
                    xfa_node 'locale', Config::Locale, 0..1
                    xfa_node 'localeSet', Config::LocaleSet, 0..1
                    xfa_node 'messaging', Config::Messaging, 0..1
                    xfa_node 'suppressBanner', Config::SuppressBanner, 0..1
                    xfa_node 'template', Config::Template, 0..1
                    xfa_node 'validationMessaging', Config::ValidationMessaging, 0..1
                    xfa_node 'versionControl', Config::VersionControl, 0..1

                    xfa_node 'log', Config::Log

                    def initialize
                        super("common")
                    end
                end

            end

            #
            # The _connectionSet_ packet describes the connections used to initiate or conduct web services.
            #
            class ConnectionSet < XFA::Element
                mime_type 'text/xml'

                def initialize
                    super("connectionSet")

                    add_attribute 'xmlns', 'http://www.xfa.org/schema/xfa-connection-set/2.8/'
                end

                class EffectiveInputPolicy < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('effectiveInputPolicy')
                    end
                end

                class EffectiveOutputPolicy < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('effectiveOutputPolicy')
                    end
                end

                class Operation < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'input'
                    xfa_attribute 'name'
                    xfa_attribute 'output'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(name = "")
                        super('operation')

                        self.text = name
                    end
                end

                class SOAPAction < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(uri = "")
                        super('soapAction')

                        self.text = uri
                    end
                end

                class SOAPAddress < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(addr = "")
                        super('soapAddress')

                        self.text = addr
                    end
                end

                class WSDLAddress < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(addr = "")
                        super('wsdlAddress')

                        self.text = addr
                    end
                end

                class WSDLConnection < XFA::Element
                    xfa_attribute 'dataDescription'
                    xfa_attribute 'name'

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

                class URI < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(uri = "")
                        super('uri')

                        self.text = uri
                    end
                end

                class RootElement < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(root = '')
                        super('rootElement')

                        self.text = root
                    end
                end

                class XSDConnection < XFA::Element
                    xfa_attribute 'dataDescription'
                    xfa_attribute 'name'

                    xfa_node 'rootElement', ConnectionSet::RootElement, 0..1
                    xfa_node 'uri', ConnectionSet::URI, 0..1

                    def initialize
                        super('xsdConnection')
                    end
                end

                class XMLConnection < XFA::Element
                    xfa_attribute 'dataDescription'
                    xfa_attribute 'name'

                    xfa_node 'uri', ConnectionSet::URI, 0..1

                    def initialize
                        super('xmlConnection')
                    end
                end

                xfa_node 'wsdlConnection', ConnectionSet::WSDLConnection
                xfa_node 'xmlConnection', ConnectionSet::XMLConnection
                xfa_node 'xsdConnection', ConnectionSet::XSDConnection
            end

            #
            # The _datasets_ element enclosed XML data content that may have originated from an XFA form and/or
            # may be intended to be consumed by an XFA form.
            #
            class Datasets < XFA::Element
                mime_type 'text/xml'

                class Data < XFA::Element
                    def initialize
                        super('xfa:data')
                    end
                end

                def initialize
                    super("xfa:datasets")

                    add_attribute 'xmlns:xfa', 'http://www.xfa.org/schema/xfa-data/1.0/'
                end
            end

            #
            # The _localeSet_ packet encloses information about locales.
            #
            class LocaleSet < XFA::Element
                mime_type 'text/xml'

                def initialize
                    super("localeSet")

                    add_attribute 'xmlns', 'http://www.xfa.org/schema/xfa-locale-set/2.7/'
                end
            end

            #
            # An XDF _pdf_ element encloses a PDF packet.
            #
            class PDF < XFA::Element
                mime_type 'application/pdf'
                xfa_attribute :href

                def initialize
                    super("pdf")

                    add_attribute 'xmlns', 'http://ns.adobe.com/xdp/pdf/'
                end

                def enclose_pdf(pdfdata)
                    require 'base64'
                    b64data = Base64.encode64(pdfdata).chomp!

                    doc = elements['document'] || add_element('document')
                    chunk = doc.elements['chunk'] || doc.add_element('chunk')

                    chunk.text = b64data

                    self
                end

                def has_enclosed_pdf?
                    chunk = elements['document/chunk']

                    not chunk.nil? and not chunk.text.nil?
                end

                def remove_enclosed_pdf
                    elements.delete('document') if has_enclosed_pdf?
                end

                def enclosed_pdf
                    return nil unless has_enclosed_pdf?

                    require 'base64'
                    Base64.decode64(elements['document/chunk'].text)
                end

            end

            #
            # The _signature_ packet encloses a detached digital signature.
            #
            class Signature < XFA::Element
                mime_type ''

                def initialize
                    super("signature")

                    add_attribute 'xmlns', 'http://www.w3.org/2000/09/xmldsig#'
                end
            end

            #
            # The _sourceSet_ packet contains ADO database queries, used to describe data
            # binding to ADO data sources.
            #
            class SourceSet < XFA::Element
                mime_type 'text/xml'

                def initialize
                    super("sourceSet")

                    add_attribute 'xmlns', 'http://www.xfa.org/schema/xfa-source-set/2.8/'
                end
            end

            #
            # The _stylesheet_ packet encloses a single XSLT stylesheet.
            #
            class StyleSheet < XFA::Element
                mime_type 'text/css'

                def initialize(id)
                    super("xsl:stylesheet")

                    add_attribute 'version', '1.0'
                    add_attribute 'xmlns:xsl', 'http://www.w3.org/1999/XSL/Transform'
                    add_attribute 'id', id.to_s
                end
            end

            #
            # This packet contains the form template.
            #
            class Template < XFA::Element
                mime_type 'application/x-xfa-template'

                class Boolean < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    NO = 0
                    YES = 1

                    def initialize(bool = nil)
                        super('boolean')

                        self.text = bool
                    end
                end

                class Date < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(date = nil)
                        super('date')

                        self.text = date
                    end
                end

                class DateTime < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(datetime = nil)
                        super('dateTime')

                        self.text = datetime
                    end
                end

                class Decimal < XFA::Element
                    xfa_attribute 'fracDigits'
                    xfa_attribute 'id'
                    xfa_attribute 'leadDigits'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(number = nil)
                        super('decimal')

                        self.text = number
                    end
                end

                class ExData < XFA::Element
                    xfa_attribute 'contentType'
                    xfa_attribute 'href'
                    xfa_attribute 'id'
                    xfa_attribute 'maxLength'
                    xfa_attribute 'name'
                    xfa_attribute 'rid'
                    xfa_attribute 'transferEncoding'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(data = nil)
                        super('exData')

                        self.text = data
                    end
                end

                class Float < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(float = nil)
                        super('float')

                        self.text = float
                    end
                end

                class Image < XFA::Element
                    xfa_attribute 'aspect'
                    xfa_attribute 'contentType'
                    xfa_attribute 'href'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'transferEncoding'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(data = nil)
                        super('image')

                        self.text = data
                    end
                end

                class Integer < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(int = nil)
                        super('integer')

                        self.text = int
                    end
                end

                class Text < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'maxChars'
                    xfa_attribute 'name'
                    xfa_attribute 'rid'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(text = "")
                        super('text')

                        self.text = text
                    end
                end

                class Time < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(time = nil)
                        super('time')

                        self.text = time
                    end
                end

                class Extras < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'boolean', Template::Boolean
                    xfa_node 'date', Template::Date
                    xfa_node 'dateTime', Template::DateTime
                    xfa_node 'decimal', Template::Decimal
                    xfa_node 'exData', Template::ExData
                    xfa_node 'extras', Template::Extras
                    xfa_node 'float', Template::Float
                    xfa_node 'image', Template::Image
                    xfa_node 'integer', Template::Integer
                    xfa_node 'text', Template::Text
                    xfa_node 'time', Template::Time

                    def initialize
                        super('extras')
                    end
                end

                class Speak < XFA::Element
                    xfa_attribute 'disable'
                    xfa_attribute 'id'
                    xfa_attribute 'priority'
                    xfa_attribute 'rid'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(text = "")
                        super('speak')

                        self.text = text
                    end
                end

                class ToolTip < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'rid'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(text = "")
                        super('toolTip')

                        self.text = text
                    end
                end

                class Assist < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'role'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'speak', Template::Speak, 0..1
                    xfa_node 'toolTip', Template::ToolTip, 0..1

                    def initialize
                        super('assist')
                    end
                end

                class Picture < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(data = nil)
                        super('picture')

                        self.text = data
                    end
                end

                class Bind < XFA::Element
                    xfa_attribute 'match'
                    xfa_attribute 'ref'

                    xfa_node 'picture', Template::Picture, 0..1

                    def initialize
                        super('bind')
                    end
                end

                class Bookend < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'leader'
                    xfa_attribute 'trailer'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('bookend')
                    end
                end

                class Color < XFA::Element
                    xfa_attribute 'cSpace'
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'value'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('color')

                        self.cSpace = "SRGB"
                    end
                end

                class Corner < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'inverted'
                    xfa_attribute 'join'
                    xfa_attribute 'presence'
                    xfa_attribute 'radius'
                    xfa_attribute 'stroke'
                    xfa_attribute 'thickness'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('corner')
                    end
                end

                class Edge < XFA::Element
                    xfa_attribute 'cap'
                    xfa_attribute 'id'
                    xfa_attribute 'presence'
                    xfa_attribute 'stroke'
                    xfa_attribute 'thickness'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('edge')
                    end
                end

                class Linear < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('linear')
                    end
                end

                class Pattern < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('pattern')
                    end
                end

                class Radial < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('radial')
                    end
                end

                class Solid < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('solid')
                    end
                end

                class Stipple < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'rate'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('stipple')
                    end
                end

                class Fill < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'presence'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'linear', Template::Linear, 0..1
                    xfa_node 'pattern', Template::Pattern, 0..1
                    xfa_node 'radial', Template::Radial, 0..1
                    xfa_node 'solid', Template::Solid, 0..1
                    xfa_node 'stipple', Template::Stipple, 0..1

                    def initialize
                        super('fill')
                    end
                end

                class Margin < XFA::Element
                    xfa_attribute 'bottomInset'
                    xfa_attribute 'id'
                    xfa_attribute 'leftInset'
                    xfa_attribute 'rightInset'
                    xfa_attribute 'topInset'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('margin')
                    end
                end

                class Border < XFA::Element
                    xfa_attribute 'break'
                    xfa_attribute 'hand'
                    xfa_attribute 'id'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'corner', Template::Corner, 0..4
                    xfa_node 'edge', Template::Edge, 0..4
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'fill', Template::Fill, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('border')
                    end
                end

                class Break < XFA::Element
                    xfa_attribute 'after'
                    xfa_attribute 'afterTarget'
                    xfa_attribute 'before'
                    xfa_attribute 'beforeTarget'
                    xfa_attribute 'bookendLeader'
                    xfa_attribute 'bookendTrailer'
                    xfa_attribute 'id'
                    xfa_attribute 'overflowLeader'
                    xfa_attribute 'overflowTarget'
                    xfa_attribute 'overflowTrailer'
                    xfa_attribute 'startNew'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('break')
                    end
                end

                class Message < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'text', Template::Text

                    def initialize
                        super('message')
                    end
                end

                class Script < XFA::Element
                    xfa_attribute 'binding'
                    xfa_attribute 'contentType'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'runAt'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(script = "")
                        super('script')

                        self.text = script
                    end
                end

                class JavaScript < Script
                    def initialize(script = "")
                        super(script)

                        self.contentType = 'application/x-javascript'
                    end
                end

                class FormCalcScript < Script
                    def initialize(script = "")
                        super(script)

                        self.contentType = 'application/x-formcalc'
                    end
                end

                class Calculate < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'override'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'message', Template::Message, 0..1
                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('calculate')
                    end
                end

                class Desc < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'boolean', Template::Boolean
                    xfa_node 'date', Template::Date
                    xfa_node 'dateTime', Template::DateTime
                    xfa_node 'decimal', Template::Decimal
                    xfa_node 'exData', Template::ExData
                    xfa_node 'float', Template::Float
                    xfa_node 'image', Template::Image
                    xfa_node 'integer', Template::Integer
                    xfa_node 'text', Template::Text
                    xfa_node 'time', Template::Time

                    def initialize
                        super('desc')
                    end
                end

                class Keep < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'intact'
                    xfa_attribute 'next'
                    xfa_attribute 'previous'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    NONE = "none"
                    CONTENTAREA = "contentArea"
                    PAGEAREA = "pageArea"

                    def initialize
                        super('keep')
                    end
                end

                class Occur < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'initial'
                    xfa_attribute 'max'
                    xfa_attribute 'min'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('occur')
                    end
                end

                class Overflow < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'leader'
                    xfa_attribute 'target'
                    xfa_attribute 'trailer'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('overflow')
                    end
                end

                class Medium < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'imagingBBox'
                    xfa_attribute 'long'
                    xfa_attribute 'orientation'
                    xfa_attribute 'short'
                    xfa_attribute 'stock'
                    xfa_attribute 'trayIn'
                    xfa_attribute 'trayOut'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('medium')
                    end
                end

                class Font < XFA::Element
                    xfa_attribute 'baselineShift'
                    xfa_attribute 'fontHorizontalScale'
                    xfa_attribute 'fontVerticalScale'
                    xfa_attribute 'id'
                    xfa_attribute 'kerningMode'
                    xfa_attribute 'letterSpacing'
                    xfa_attribute 'lineThrough'
                    xfa_attribute 'lineThroughPeriod'
                    xfa_attribute 'overline'
                    xfa_attribute 'overlinePeriod'
                    xfa_attribute 'posture'
                    xfa_attribute 'size'
                    xfa_attribute 'typeface'
                    xfa_attribute 'underline'
                    xfa_attribute 'underlinePeriod'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'weight'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'fill', Template::Fill, 0..1

                    def initialize
                        super('font')
                    end
                end

                class Hyphenation < XFA::Element
                    xfa_attribute 'excludeAllCaps'
                    xfa_attribute 'excludeInitialCap'
                    xfa_attribute 'hyphenate'
                    xfa_attribute 'id'
                    xfa_attribute 'pushCharacterCount'
                    xfa_attribute 'remainCharacterCount'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'wordCharacterCount'

                    def initialize
                        super('hyphenation')
                    end
                end

                class Para < XFA::Element
                    xfa_attribute 'hAlign'
                    xfa_attribute 'id'
                    xfa_attribute 'lineHeight'
                    xfa_attribute 'marginLeft'
                    xfa_attribute 'marginRight'
                    xfa_attribute 'orphans'
                    xfa_attribute 'preserve'
                    xfa_attribute 'radixOffset'
                    xfa_attribute 'spaceAbove'
                    xfa_attribute 'spaceBelow'
                    xfa_attribute 'tabDefault'
                    xfa_attribute 'tabStops'
                    xfa_attribute 'textIndent'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'vAlign'
                    xfa_attribute 'widows'

                    xfa_node 'hyphenation', Template::Hyphenation, 0..1

                    def initialize
                        super('para')
                    end
                end

                class Arc < XFA::Element
                    xfa_attribute 'circular'
                    xfa_attribute 'hand'
                    xfa_attribute 'id'
                    xfa_attribute 'startAngle'
                    xfa_attribute 'sweepAngle'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'edge', Template::Edge, 0..1
                    xfa_node 'fill', Template::Fill, 0..1

                    def initialize
                        super('arc')
                    end
                end

                class Line < XFA::Element
                    xfa_attribute 'hand'
                    xfa_attribute 'id'
                    xfa_attribute 'slope'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'edge', Template::Edge, 0..1

                    def initialize
                        super('line')
                    end
                end

                class Rectangle < XFA::Element
                    xfa_attribute 'hand'
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'corner', Template::Corner, 0..4
                    xfa_node 'edge', Template::Edge, 0..4
                    xfa_node 'fill', Template::Fill, 0..4

                    def initialize
                        super('rectangle')
                    end
                end

                class Value < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'override'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'arc', Template::Arc, 0..1
                    xfa_node 'boolean', Template::Boolean, 0..1
                    xfa_node 'date', Template::Date, 0..1
                    xfa_node 'dateTime', Template::DateTime, 0..1
                    xfa_node 'decimal', Template::Decimal, 0..1
                    xfa_node 'exData', Template::ExData, 0..1
                    xfa_node 'float', Template::Float, 0..1
                    xfa_node 'image', Template::Image, 0..1
                    xfa_node 'integer', Template::Integer, 0..1
                    xfa_node 'line', Template::Line, 0..1
                    xfa_node 'rectangle', Template::Rectangle, 0..1
                    xfa_node 'text', Template::Text, 0..1
                    xfa_node 'time', Template::Time, 0..1

                    def initialize
                        super('value')
                    end
                end

                class Caption < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'placement'
                    xfa_attribute 'presence'
                    xfa_attribute 'reserve'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'font', Template::Font, 0..1
                    xfa_node 'margin', Template::Margin, 0..1
                    xfa_node 'para', Template::Para, 0..1
                    xfa_node 'value', Template::Value, 0..1

                    def initialize
                        super('caption')
                    end
                end

                class Traverse < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'operation'
                    xfa_attribute 'ref'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('traverse')
                    end
                end

                class Traversal < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    xfa_node 'traverse', Template::Traverse

                    def initialize
                        super('traversal')
                    end
                end

                class Certificate < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(b64data = nil)
                        super('certificate')

                        self.text = b64data
                    end
                end

                class Encrypt < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'certificate', Template::Certificate, 0..1

                    def initialize
                        super('encrypt')
                    end
                end

                class Barcode < XFA::Element
                    xfa_attribute 'charEncoding'
                    xfa_attribute 'checksum'
                    xfa_attribute 'dataColumnCount'
                    xfa_attribute 'dataLength'
                    xfa_attribute 'dataPrep'
                    xfa_attribute 'dataRowCount'
                    xfa_attribute 'endChar'
                    xfa_attribute 'errorConnectionLevel'
                    xfa_attribute 'id'
                    xfa_attribute 'moduleHeight'
                    xfa_attribute 'moduleWidth'
                    xfa_attribute 'printCheckDigit'
                    xfa_attribute 'rowColumnRatio'
                    xfa_attribute 'startChar'
                    xfa_attribute 'textLocation'
                    xfa_attribute 'truncate'
                    xfa_attribute 'type'
                    xfa_attribute 'upsMode'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'wideNarrowRatio'

                    xfa_node 'encrypt', Template::Encrypt, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('barcode')
                    end
                end

                class Button < XFA::Element
                    xfa_attribute 'highlight'
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('button')
                    end
                end

                class CheckButton < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'mark'
                    xfa_attribute 'shape'
                    xfa_attribute 'size'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('checkButton')
                    end
                end

                class ChoiceList < XFA::Element
                    xfa_attribute 'commitOn'
                    xfa_attribute 'id'
                    xfa_attribute 'open'
                    xfa_attribute 'textEntry'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('choiceList')
                    end
                end

                class Comb < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'numberOfCells'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('comb')
                    end
                end

                class DateTimeEdit < XFA::Element
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'id'
                    xfa_attribute 'picker'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'comb', Template::Comb, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('dateTimeEdit')
                    end
                end

                class DefaultUI < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('defaultUi')
                    end
                end

                class ImageEdit < XFA::Element
                    xfa_attribute 'data'
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('imageEdit')
                    end
                end

                class NumericEdit < XFA::Element
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'comb', Template::Comb, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('numericEdit')
                    end
                end

                class PasswordEdit < XFA::Element
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'id'
                    xfa_attribute 'passwordChar'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('passwordEdit')
                    end
                end

                class AppearanceFilter < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(name = "")
                        super('appearanceFilter')

                        self.text = name
                    end
                end

                class Issuers < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'certificate', Template::Certificate

                    def initialize
                        super('issuers')
                    end
                end

                class KeyUsage < XFA::Element
                    xfa_attribute 'crlSign'
                    xfa_attribute 'dataEncipherment'
                    xfa_attribute 'decipherOnly'
                    xfa_attribute 'digitalSignature'
                    xfa_attribute 'encipherOnly'
                    xfa_attribute 'id'
                    xfa_attribute 'keyAgreement'
                    xfa_attribute 'keyCertSign'
                    xfa_attribute 'keyEncipherment'
                    xfa_attribute 'nonRepudiation'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('keyUsage')
                    end
                end

                class OID < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(oid = "")
                        super('oid')

                        self.text = oid
                    end
                end

                class OIDs < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'oid', Template::OID

                    def initialize
                        super('oids')
                    end
                end

                class Signing < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'certificate', Template::Certificate

                    def initialize
                        super('signing')
                    end
                end

                class SubjectDN < XFA::Element
                    xfa_attribute 'delimiter'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(data = "")
                        super('subjectDN')

                        self.text = data
                    end
                end

                class SubjectDNs < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'subjectDN', Template::SubjectDN, 0..1

                    def initialize
                        super('subjectDNs')
                    end
                end

                class Certificates < XFA::Element
                    xfa_attribute 'credentialServerPolicy'
                    xfa_attribute 'id'
                    xfa_attribute 'url'
                    xfa_attribute 'urlPolicy'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'issuers', Template::Issuers, 0..1
                    xfa_node 'keyUsage', Template::KeyUsage, 0..1
                    xfa_node 'oids', Template::OIDs, 0..1
                    xfa_node 'signing', Template::Signing, 0..1
                    xfa_node 'subjectDNs', Template::SubjectDNs, 0..1

                    def initialize
                        super('certificates')
                    end
                end

                class DigestMethod < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(method = "")
                        super('digestMethod')

                        self.text = method
                    end
                end

                class DigestMethods < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'digestMethod', Template::DigestMethod

                    def initialize
                        super('digestMethods')
                    end
                end

                class Encoding < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(encoding = "")
                        super('encoding')

                        self.text = encoding
                    end
                end

                class Encodings < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'encoding', Template::Encoding

                    def initialize
                        super('encodings')
                    end
                end

                class Handler < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(handler = "")
                        super('handler')

                        self.text = handler
                    end
                end

                class LockDocument < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(lock = "default")
                        super('lockDocument')

                        self.text = lock
                    end
                end

                class MDP < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'permissions'
                    xfa_attribute 'signatureType'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('mdp')
                    end
                end

                class Reason < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(reason = "")
                        super('reason')

                        self.text = reason
                    end
                end

                class Reasons < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'reason', Template::Reason

                    def initialize
                        super('reasons')
                    end
                end

                class TimeStamp < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'server'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('timeStamp')
                    end
                end

                class Filter < XFA::Element
                    xfa_attribute 'addRevocationInfo'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'version'

                    xfa_node 'appearanceFilter', Template::AppearanceFilter, 0..1
                    xfa_node 'certificates', Template::Certificates, 0..1
                    xfa_node 'digestMethods', Template::DigestMethods, 0..1
                    xfa_node 'encodings', Template::Encodings, 0..1
                    xfa_node 'handler', Template::Handler, 0..1
                    xfa_node 'lockDocument', Template::LockDocument, 0..1
                    xfa_node 'mdp', Template::MDP, 0..1
                    xfa_node 'reasons', Template::Reasons, 0..1
                    xfa_node 'timeStamp', Template::TimeStamp, 0..1

                    def initialize
                        super('filter')
                    end
                end

                class Ref < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize(somexpr = nil)
                        super('ref')

                        self.text = somexpr
                    end
                end

                class Manifest < XFA::Element
                    xfa_attribute 'action'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    xfa_node 'ref', Template::Ref, 0..1

                    def initialize
                        super('manifest')
                    end
                end

                class Signature < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'type'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'filter', Template::Filter, 0..1
                    xfa_node 'manifest', Template::Manifest, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('signature')
                    end
                end

                class TextEdit < XFA::Element
                    xfa_attribute 'allowRichText'
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'id'
                    xfa_attribute 'multiLine'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'vScrollPolicy'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'comb', Template::Comb, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('textEdit')
                    end
                end

                class UI < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'picture', Template::Picture, 0..1
                    xfa_node 'barcode', Template::Barcode, 0..1
                    xfa_node 'button', Template::Button, 0..1
                    xfa_node 'checkButton', Template::CheckButton, 0..1
                    xfa_node 'choiceList', Template::ChoiceList, 0..1
                    xfa_node 'dateTimeEdit', Template::DateTimeEdit, 0..1
                    xfa_node 'defaultUi', Template::DefaultUI, 0..1
                    xfa_node 'imageEdit', Template::ImageEdit, 0..1
                    xfa_node 'numericEdit', Template::NumericEdit, 0..1
                    xfa_node 'passwordEdit', Template::PasswordEdit, 0..1
                    xfa_node 'signature', Template::Signature, 0..1
                    xfa_node 'textEdit', Template::TextEdit, 0..1

                    def initialize
                        super('ui')
                    end
                end

                class SetProperty < XFA::Element
                    xfa_attribute 'connection'
                    xfa_attribute 'ref'
                    xfa_attribute 'target'

                    def initialize
                        super('setProperty')
                    end
                end

                class Draw < XFA::Element
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'h'
                    xfa_attribute 'id'
                    xfa_attribute 'locale'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'name'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'rotate'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'w'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'assist', Template::Assist, 0..1
                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'caption', Template::Caption, 0..1
                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'font', Template::Font, 0..1
                    xfa_node 'keep', Template::Keep, 0..1
                    xfa_node 'margin', Template::Margin, 0..1
                    xfa_node 'para', Template::Para, 0..1
                    xfa_node 'traversal', Template::Traversal, 0..1
                    xfa_node 'ui', Template::UI, 0..1
                    xfa_node 'value', Template::Value, 0..1

                    xfa_node 'setProperty', Template::SetProperty

                    def initialize
                        super('draw')
                    end
                end

                class Validate < XFA::Element
                    xfa_attribute 'formatTest'
                    xfa_attribute 'id'
                    xfa_attribute 'nullTest'
                    xfa_attribute 'scriptTest'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'message', Template::Message, 0..1
                    xfa_node 'picture', Template::Picture, 0..1
                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('validate')
                    end
                end

                class Connect < XFA::Element
                    xfa_attribute 'connection'
                    xfa_attribute 'id'
                    xfa_attribute 'ref'
                    xfa_attribute 'usage'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'picture', Template::Picture, 0..1

                    def initialize
                        super('connect')
                    end
                end

                class Execute < XFA::Element
                    xfa_attribute 'connection'
                    xfa_attribute 'executeType'
                    xfa_attribute 'id'
                    xfa_attribute 'runAt'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    def initialize
                        super('execute')
                    end
                end

                class SignData < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'operation'
                    xfa_attribute 'ref'
                    xfa_attribute 'target'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'filter', Template::Filter, 0..1
                    xfa_node 'manifest', Template::Manifest, 0..1

                    def initialize
                        super('signData')
                    end
                end

                class Submit < XFA::Element
                    xfa_attribute 'embedPDF'
                    xfa_attribute 'format'
                    xfa_attribute 'id'
                    xfa_attribute 'target'
                    xfa_attribute 'textEncoding'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'xdpContent'

                    xfa_node 'encrypt', Template::Encrypt, 0..1

                    xfa_node 'signData', Template::SignData

                    def initialize
                        super('submit')
                    end
                end

                class Event < XFA::Element
                    xfa_attribute 'activity'
                    xfa_attribute 'id'
                    xfa_attribute 'listen'
                    xfa_attribute 'name'
                    xfa_attribute 'ref'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'execute', Template::Execute, 0..1
                    xfa_node 'script', Template::Script, 0..1
                    xfa_node 'signData', Template::SignData, 0..1
                    xfa_node 'submit', Template::Submit, 0..1

                    def initialize
                        super('event')
                    end
                end

                class Format < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'picture', Template::Picture, 0..1

                    def initialize
                        super('format')
                    end
                end

                class Items < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'presence'
                    xfa_attribute 'ref'
                    xfa_attribute 'save'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'boolean', Template::Boolean
                    xfa_node 'date', Template::Date
                    xfa_node 'dateTime', Template::DateTime
                    xfa_node 'decimal', Template::Decimal
                    xfa_node 'exData', Template::ExData
                    xfa_node 'float', Template::Float
                    xfa_node 'image', Template::Image
                    xfa_node 'integer', Template::Integer
                    xfa_node 'text', Template::Text
                    xfa_node 'time', Template::Time

                    def initialize
                        super('items')
                    end
                end

                class BindItems < XFA::Element
                    xfa_attribute 'connection'
                    xfa_attribute 'labelRef'
                    xfa_attribute 'ref'
                    xfa_attribute 'valueRef'

                    def initialize
                        super('bindItems')
                    end
                end

                class Field < XFA::Element
                    xfa_attribute 'access'
                    xfa_attribute 'accessKey'
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'h'
                    xfa_attribute 'id'
                    xfa_attribute 'locale'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'name'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'rotate'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'w'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'assist', Template::Assist, 0..1
                    xfa_node 'bind', Template::Bind, 0..1
                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'calculate', Template::Calculate, 0..1
                    xfa_node 'caption', Template::Caption, 0..1
                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'font', Template::Font, 0..1
                    xfa_node 'format', Template::Format, 0..1
                    xfa_node 'items', Template::Items, 0..2
                    xfa_node 'keep', Template::Keep, 0..1
                    xfa_node 'margin', Template::Margin, 0..1
                    xfa_node 'para', Template::Para, 0..1
                    xfa_node 'traversal', Template::Traversal, 0..1
                    xfa_node 'ui', Template::UI, 0..1
                    xfa_node 'validate', Template::Validate, 0..1
                    xfa_node 'value', Template::Value, 0..1

                    xfa_node 'bindItems', Template::BindItems
                    xfa_node 'connect', Template::Connect
                    xfa_node 'event', Template::Event
                    xfa_node 'setProperty', Template::SetProperty

                    def initialize
                        super('field')
                    end
                end


                class ExclGroup < XFA::Element
                    xfa_attribute 'access'
                    xfa_attribute 'accessKey'
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'h'
                    xfa_attribute 'id'
                    xfa_attribute 'layout'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'name'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'w'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'assist', Template::Assist, 0..1
                    xfa_node 'bind', Template::Bind, 0..1
                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'calculate', Template::Calculate, 0..1
                    xfa_node 'caption', Template::Caption, 0..1
                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1
                    xfa_node 'para', Template::Para, 0..1
                    xfa_node 'traversal', Template::Traversal, 0..1
                    xfa_node 'validate', Template::Validate, 0..1

                    xfa_node 'connect', Template::Connect
                    xfa_node 'event', Template::Event
                    xfa_node 'field', Template::Field
                    xfa_node 'setProperty', Template::SetProperty

                    def initialize
                        super('exclGroup')
                    end
                end

                class BreakAfter < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'leader'
                    xfa_attribute 'startNew'
                    xfa_attribute 'target'
                    xfa_attribute 'targetType'
                    xfa_attribute 'trailer'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('breakAfter')
                    end
                end

                class BreakBefore < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'leader'
                    xfa_attribute 'startNew'
                    xfa_attribute 'target'
                    xfa_attribute 'targetType'
                    xfa_attribute 'trailer'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('breakBefore')
                    end
                end

                class Subform < XFA::Element ; end
                class SubformSet < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'relation'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'bookend', Template::Bookend, 0..1
                    xfa_node 'break', Template::Break, 0..1
                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'occur', Template::Occur, 0..1
                    xfa_node 'overflow', Template::Overflow, 0..1

                    xfa_node 'breakAfter', Template::BreakAfter
                    xfa_node 'breakBefore', Template::BreakBefore
                    xfa_node 'subform', Template::Subform
                    xfa_node 'subformSet', Template::SubformSet

                    def initialize
                        super('subformSet')
                    end
                end

                class Area < XFA::Element
                    xfa_attribute 'colSpan'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    xfa_node 'area', Template::Area
                    xfa_node 'draw', Template::Draw
                    xfa_node 'exclGroup', Template::ExclGroup
                    xfa_node 'field', Template::Field
                    xfa_node 'subform', Template::Subform
                    xfa_node 'subformSet', Template::SubformSet

                    def initialize
                        super('area')
                    end
                end

                class ContentArea < XFA::Element
                    xfa_attribute 'h'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'w'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('contentArea')
                    end
                end

                class PageArea < XFA::Element
                    xfa_attribute 'blankOrNotBlank'
                    xfa_attribute 'id'
                    xfa_attribute 'initialNumber'
                    xfa_attribute 'name'
                    xfa_attribute 'numbered'
                    xfa_attribute 'oddOrEven'
                    xfa_attribute 'pagePosition'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'medium', Template::Medium, 0..1
                    xfa_node 'occur', Template::Occur, 0..1

                    xfa_node 'area', Template::Area
                    xfa_node 'contentArea', Template::ContentArea
                    xfa_node 'draw', Template::Draw
                    xfa_node 'exclGroup', Template::ExclGroup
                    xfa_node 'field', Template::Field
                    xfa_node 'subform', Template::Subform

                    def initialize
                        super('pageArea')
                    end
                end

                class PageSet < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'relation'
                    xfa_attribute 'relevant'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'occur', Template::Occur, 0..1

                    xfa_node 'pageArea', Template::PageArea
                    xfa_node 'pageSet', Template::PageSet

                    ORDERED_OCCURENCE = "orderedOccurence"
                    DUPLEX_PAGINATED = "duplexPaginated"
                    SIMPLEX_PAGINATED = "simplexPaginated"

                    def initialize
                        super('pageSet')
                    end
                end

                class Variables < XFA::Element
                    xfa_attribute 'id'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'boolean', Template::Boolean
                    xfa_node 'date', Template::Date
                    xfa_node 'dateTime', Template::DateTime
                    xfa_node 'decimal', Template::Decimal
                    xfa_node 'exData', Template::ExData
                    xfa_node 'float', Template::Float
                    xfa_node 'image', Template::Image
                    xfa_node 'integer', Template::Integer
                    xfa_node 'manifest', Template::Manifest
                    xfa_node 'script', Template::Script
                    xfa_node 'text', Template::Text
                    xfa_node 'time', Template::Time

                    def initialize
                        super('variables')
                    end
                end

                class ExObject < XFA::Element
                    xfa_attribute 'archive'
                    xfa_attribute 'classId'
                    xfa_attribute 'codeBase'
                    xfa_attribute 'codeType'
                    xfa_attribute 'id'
                    xfa_attribute 'name'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'

                    xfa_node 'extras', Template::Extras, 0..1

                    xfa_node 'boolean', Template::Boolean
                    xfa_node 'date', Template::Date
                    xfa_node 'dateTime', Template::DateTime
                    xfa_node 'decimal', Template::Decimal
                    xfa_node 'exData', Template::ExData
                    xfa_node 'exObject', Template::ExObject
                    xfa_node 'float', Template::Float
                    xfa_node 'image', Template::Image
                    xfa_node 'integer', Template::Integer
                    xfa_node 'text', Template::Text
                    xfa_node 'time', Template::Time

                    def initialize
                        super('exObject')
                    end
                end

                class Proto < XFA::Element
                    xfa_node 'appearanceFilter', Template::AppearanceFilter
                    xfa_node 'arc', Template::Arc
                    xfa_node 'area', Template::Area
                    xfa_node 'assist', Template::Assist
                    xfa_node 'barcode', Template::Barcode
                    xfa_node 'bindItems', Template::BindItems
                    xfa_node 'bookend', Template::Bookend
                    xfa_node 'boolean', Template::Boolean
                    xfa_node 'border', Template::Border
                    xfa_node 'break', Template::Break
                    xfa_node 'breakAfter', Template::BreakAfter
                    xfa_node 'breakBefore', Template::BreakBefore
                    xfa_node 'button', Template::Button
                    xfa_node 'calculate', Template::Calculate
                    xfa_node 'caption', Template::Caption
                    xfa_node 'certificate', Template::Certificate
                    xfa_node 'certificates', Template::Certificates
                    xfa_node 'checkButton', Template::CheckButton
                    xfa_node 'choiceList', Template::ChoiceList
                    xfa_node 'color', Template::Color
                    xfa_node 'comb', Template::Comb
                    xfa_node 'connect', Template::Connect
                    xfa_node 'contentArea', Template::ContentArea
                    xfa_node 'corner', Template::Corner
                    xfa_node 'date', Template::Date
                    xfa_node 'dateTime', Template::DateTime
                    xfa_node 'dateTimeEdit', Template::DateTimeEdit
                    xfa_node 'decimal', Template::Decimal
                    xfa_node 'defaultUi', Template::DefaultUI
                    xfa_node 'desc', Template::Desc
                    xfa_node 'digestMethod', Template::DigestMethod
                    xfa_node 'digestMethods', Template::DigestMethods
                    xfa_node 'draw', Template::Draw
                    xfa_node 'edge', Template::Edge
                    xfa_node 'encoding', Template::Encoding
                    xfa_node 'encodings', Template::Encodings
                    xfa_node 'encrypt', Template::Encrypt
                    xfa_node 'event', Template::Event
                    xfa_node 'exData', Template::ExData
                    xfa_node 'exObject', Template::ExObject
                    xfa_node 'exclGroup', Template::ExclGroup
                    xfa_node 'execute', Template::Execute
                    xfa_node 'extras', Template::Extras
                    xfa_node 'field', Template::Field
                    xfa_node 'fill', Template::Fill
                    xfa_node 'filter', Template::Filter
                    xfa_node 'float', Template::Float
                    xfa_node 'font', Template::Font
                    xfa_node 'format', Template::Format
                    xfa_node 'handler', Template::Handler
                    xfa_node 'hyphenation', Template::Hyphenation
                    xfa_node 'image', Template::Image
                    xfa_node 'imageEdit', Template::ImageEdit
                    xfa_node 'integer', Template::Integer
                    xfa_node 'issuers', Template::Issuers
                    xfa_node 'items', Template::Items
                    xfa_node 'keep', Template::Keep
                    xfa_node 'keyUsage', Template::KeyUsage
                    xfa_node 'line', Template::Line
                    xfa_node 'linear', Template::Linear
                    xfa_node 'lockDocument', Template::LockDocument
                    xfa_node 'manifest', Template::Manifest
                    xfa_node 'margin', Template::Margin
                    xfa_node 'mdp', Template::MDP
                    xfa_node 'medium', Template::Medium
                    xfa_node 'message', Template::Message
                    xfa_node 'numericEdit', Template::NumericEdit
                    xfa_node 'occur', Template::Occur
                    xfa_node 'oid', Template::OID
                    xfa_node 'oids', Template::OIDs
                    xfa_node 'overflow', Template::Overflow
                    xfa_node 'pageArea', Template::PageArea
                    xfa_node 'pageSet', Template::PageSet
                    xfa_node 'para', Template::Para
                    xfa_node 'passwordEdit', Template::PasswordEdit
                    xfa_node 'pattern', Template::Pattern
                    xfa_node 'picture', Template::Picture
                    xfa_node 'radial', Template::Radial
                    xfa_node 'reason', Template::Reason
                    xfa_node 'reasons', Template::Reasons
                    xfa_node 'rectangle', Template::Rectangle
                    xfa_node 'ref', Template::Ref
                    xfa_node 'script', Template::Script
                    xfa_node 'setProperty', Template::SetProperty
                    xfa_node 'signData', Template::SignData
                    xfa_node 'signature', Template::Signature
                    xfa_node 'signing', Template::Signing
                    xfa_node 'solid', Template::Solid
                    xfa_node 'speak', Template::Speak
                    xfa_node 'stipple', Template::Stipple
                    xfa_node 'subform', Template::Subform
                    xfa_node 'subformSet', Template::SubformSet
                    xfa_node 'subjectDN', Template::SubjectDN
                    xfa_node 'subjectDNs', Template::SubjectDNs
                    xfa_node 'submit', Template::Submit
                    xfa_node 'text', Template::Text
                    xfa_node 'textEdit', Template::TextEdit
                    xfa_node 'time', Template::Time
                    xfa_node 'timeStamp', Template::TimeStamp
                    xfa_node 'toolTip', Template::ToolTip
                    xfa_node 'traversal', Template::Traversal
                    xfa_node 'traverse', Template::Traverse
                    xfa_node 'ui', Template::UI
                    xfa_node 'validate', Template::Validate
                    xfa_node 'value', Template::Value
                    xfa_node 'variables', Template::Variables

                    def initialize
                        super('proto')
                    end
                end

                class Subform < XFA::Element
                    xfa_attribute 'access'
                    xfa_attribute 'allowMacro'
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'columnWidths'
                    xfa_attribute 'h'
                    xfa_attribute 'id'
                    xfa_attribute 'layout'
                    xfa_attribute 'locale'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'name'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'restoreState'
                    xfa_attribute 'scope'
                    xfa_attribute 'use'
                    xfa_attribute 'usehref'
                    xfa_attribute 'w'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'assist', Template::Assist, 0..1
                    xfa_node 'bind', Template::Bind, 0..1
                    xfa_node 'bookend', Template::Bookend, 0..1
                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'break', Template::Break, 0..1
                    xfa_node 'calculate', Template::Calculate, 0..1
                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'keep', Template::Keep, 0..1
                    xfa_node 'margin', Template::Margin, 0..1
                    xfa_node 'occur', Template::Occur, 0..1
                    xfa_node 'overflow', Template::Overflow, 0..1
                    xfa_node 'pageSet', Template::PageSet, 0..1
                    xfa_node 'para', Template::Para, 0..1
                    xfa_node 'traversal', Template::Traversal, 0..1
                    xfa_node 'validate', Template::Validate, 0..1
                    xfa_node 'variables', Template::Variables, 0..1

                    xfa_node 'area', Template::Area
                    xfa_node 'breakAfter', Template::BreakAfter
                    xfa_node 'breakBefore', Template::BreakBefore
                    xfa_node 'connect', Template::Connect
                    xfa_node 'draw', Template::Draw
                    xfa_node 'event', Template::Event
                    xfa_node 'exObject', Template::ExObject
                    xfa_node 'exclGroup', Template::ExclGroup
                    xfa_node 'field', Template::Field
                    xfa_node 'proto', Template::Proto
                    xfa_node 'setProperty', Template::SetProperty
                    xfa_node 'subform', Template::Subform
                    xfa_node 'subformSet', Template::SubformSet

                    def initialize
                        super('subform')
                    end
                end

                xfa_attribute 'baseProfile'
                xfa_node 'extras', Template::Extras, 0..1

                xfa_node 'subform', Template::Subform

                def initialize
                    super("template")

                    add_attribute 'xmlns:xfa', 'http://www.xfa.org/schema/xfa-template/3.0/'
                end
            end

            #
            # The _xdc_ packet encloses application-specific XFA driver configuration instruction.
            #
            class XDC < XFA::Element
                mime_type ''

                def initialize
                    super("xsl:xdc")

                    add_attribute 'xmlns:xdc', 'http://www.xfa.org/schema/xdc/1.0/'
                end
            end

            #
            # The _xfdf_ (annotations) packet enclosed collaboration annotations placed upon a PDF document.
            #
            class XFDF < XFA::Element
                mime_type 'application/vnd.adobe.xfdf'

                def initialize
                    super("xfdf")

                    add_attribute 'xmlns', 'http://ns.adobe.com/xfdf/'
                    add_attribute 'xml:space', 'preserve'
                end
            end

            #
            # An _XMP_ packet contains XML representation of PDF metadata.
            #
            class XMPMeta < XFA::Element
                mime_type 'application/rdf+xml'

                def initialize
                    super("xmpmeta")

                    add_attribute 'xmlns', 'http://ns.adobe.com/xmpmeta/'
                    add_attribute 'xml:space', 'preserve'
                end
            end

        end

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
