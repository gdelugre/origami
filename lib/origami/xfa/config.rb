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
        class ConfigElement < Element
            include Lockable
            include Descriptive
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

                class URI < XFA::ConfigElement
                    def initialize(uri = "")
                        super('uri')

                        self.text = uri
                    end
                end

                class Debug < XFA::ConfigElement
                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('debug')
                    end
                end

                class AdjustData < XFA::ConfigElement
                    def initialize(coercion = "0")
                        super('adjustData')

                        self.text = coercion
                    end
                end

                class Attributes < XFA::ConfigElement
                    PRESERVE = "preserve"
                    DELEGATE = "delegate"
                    IGNORE = "ignore"

                    def initialize(attr = PRESERVE)
                        super('attributes')

                        self.text = attr
                    end
                end

                class IncrementalLoad < XFA::ConfigElement
                    NONE = "none"
                    FORWARDONLY = "forwardOnly"

                    def initialize(incload = NONE)
                        super('incrementalLoad')

                        self.text = incload
                    end
                end

                class Locale < XFA::ConfigElement
                    def initialize(locale = "")
                        super('locale')

                        self.text = locale
                    end
                end

                class LocaleSet < XFA::ConfigElement
                    def initialize(uri = "")
                        super('localeSet')

                        self.text = uri
                    end
                end

                class OutputXSL < XFA::ConfigElement
                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('outputXSL')
                    end
                end

                class Range < XFA::ConfigElement
                    def initialize(range = "")
                        super('range')

                        self.text = range
                    end
                end

                class Record < XFA::ConfigElement
                    def initialize(record = "")
                        super('record')

                        self.text = record
                    end
                end

                class StartNode < XFA::ConfigElement
                    def initialize(somexpr = "")
                        super('startNode')

                        self.text = somexpr
                    end
                end

                class Window < XFA::ConfigElement
                    def initialize(win = "0")
                        super('window')

                        self.text = win
                    end
                end

                class XSL < XFA::ConfigElement
                    xfa_node 'debug', Config::Debug, 0..1
                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('xsl')
                    end
                end

                class ExcludeNS < XFA::ConfigElement
                    def initialize(ns = "")
                        super('excludeNS')

                        self.text = ns
                    end
                end

                class GroupParent < XFA::ConfigElement
                    def initialize(parentname = "")
                        super('groupParent')

                        self.text = parentname
                    end
                end

                class IfEmpty < XFA::ConfigElement
                    DATAVALUE = "dataValue"
                    DATAGROUP = "dataGroup"
                    IGNORE = "ignore"
                    REMOVE = "remove"

                    def initialize(default = DATAVALUE)
                        super('ifEmpty')

                        self.text = default
                    end
                end

                class NameAttr < XFA::ConfigElement
                    def initialize(name)
                        super('nameAttr')

                        self.text = name
                    end
                end

                class Picture < XFA::ConfigElement
                    def initialize(clause = "")
                        super('picture')

                        self.text = clause
                    end
                end

                class Presence < XFA::ConfigElement
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

                class Rename < XFA::ConfigElement
                    def initialize(nodename = "")
                        super('rename')

                        self.text = nodename
                    end
                end

                class Whitespace < XFA::ConfigElement
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

                class Transform < XFA::ConfigElement
                    xfa_attribute 'ref'

                    xfa_node 'groupParent', Config::GroupParent, 0..1
                    xfa_node 'ifEmpty', Config::IfEmpty, 0..1
                    xfa_node 'nameAttr', Config::NameAttr, 0..1
                    xfa_node 'picture', Config::Picture, 0..1
                    xfa_node 'presence', Config::Presence, 0..1
                    xfa_node 'rename', Config::Rename, 0..1
                    xfa_node 'whitespace', Config::Whitespace, 0..1
                end

                class Data < XFA::ConfigElement
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

                class Severity < XFA::ConfigElement
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

                class MsgId < XFA::ConfigElement
                    def initialize(uid = "1")
                        super('msgId')

                        self.text = uid
                    end
                end

                class Message < XFA::ConfigElement
                    xfa_node 'msgId', Config::MsgId, 0..1
                    xfa_node 'severity', Config::Severity, 0..1

                    def initialize
                        super('message')
                    end
                end

                class Messaging < XFA::ConfigElement
                    xfa_node 'message', Config::Message

                    def initialize
                        super('messaging')
                    end
                end

                class SuppressBanner < XFA::ConfigElement
                    ALLOWED = "0"
                    DENIED = "1"

                    def initialize(display = ALLOWED)
                        super('suppressBanner')

                        self.text = display
                    end
                end

                class Base < XFA::ConfigElement
                    def initialize(uri = "")
                        super('base')

                        self.text = uri
                    end
                end

                class Relevant < XFA::ConfigElement
                    def initialize(token = "")
                        super('relevant')

                        self.text = token
                    end
                end

                class StartPage < XFA::ConfigElement
                    def initialize(pagenum = "0")
                        super('startPage')

                        self.text = pagenum
                    end
                end

                class Template < XFA::ConfigElement
                    xfa_node 'base', Config::Base, 0..1
                    xfa_node 'relevant', Config::Relevant, 0..1
                    xfa_node 'startPage', Config::StartPage, 0..1
                    xfa_node 'uri', Config::URI, 0..1
                    xfa_node 'xsl', Config::XSL, 0..1

                    def initialize
                        super('template')
                    end
                end

                class ValidationMessaging < XFA::ConfigElement
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
                    include Lockable

                    xfa_attribute 'outputBelow'
                    xfa_attribute 'sourceAbove'
                    xfa_attribute 'sourceBelow'

                    def initialize
                        super('versionControl')
                    end
                end

                class Mode < XFA::ConfigElement
                    APPEND = "append"
                    OVERWRITE = "overwrite"

                    def initialize(mode = APPEND)
                        super('mode')

                        self.text = mode
                    end
                end

                class Threshold < XFA::ConfigElement
                    TRACE = "trace"
                    ERROR = "error"
                    INFORMATION = "information"
                    WARN = "warn"

                    def initialize(threshold = TRACE)
                        super('threshold')

                        self.text = threshold
                    end
                end

                class To < XFA::ConfigElement
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

                class Log < XFA::ConfigElement
                    xfa_node 'mode', Config::Mode, 0..1
                    xfa_node 'threshold', Config::Threshold, 0..1
                    xfa_node 'to', Config::To, 0..1
                    xfa_node 'uri', Config::URI, 0..1

                    def initialize
                        super('log')
                    end
                end

                class Common < XFA::ConfigElement
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

        end
    end
end
