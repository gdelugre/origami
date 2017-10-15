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

    module XDP

        module Packet

            #
            # This packet contains the form template.
            #
            class Template < XFA::Element
                mime_type 'application/x-xfa-template'

                class Boolean < XFA::NamedTemplateElement
                    NO = 0
                    YES = 1

                    def initialize(bool = nil)
                        super('boolean')

                        self.text = bool
                    end
                end

                class Date < XFA::NamedTemplateElement
                    def initialize(date = nil)
                        super('date')

                        self.text = date
                    end
                end

                class DateTime < XFA::NamedTemplateElement
                    def initialize(datetime = nil)
                        super('dateTime')

                        self.text = datetime
                    end
                end

                class Decimal < XFA::NamedTemplateElement
                    xfa_attribute 'fracDigits'
                    xfa_attribute 'leadDigits'

                    def initialize(number = nil)
                        super('decimal')

                        self.text = number
                    end
                end

                class ExData < XFA::NamedTemplateElement
                    xfa_attribute 'contentType'
                    xfa_attribute 'href'
                    xfa_attribute 'maxLength'
                    xfa_attribute 'rid'
                    xfa_attribute 'transferEncoding'

                    def initialize(data = nil)
                        super('exData')

                        self.text = data
                    end
                end

                class Float < XFA::NamedTemplateElement
                    def initialize(float = nil)
                        super('float')

                        self.text = float
                    end
                end

                class Image < XFA::NamedTemplateElement
                    xfa_attribute 'aspect'
                    xfa_attribute 'contentType'
                    xfa_attribute 'href'
                    xfa_attribute 'transferEncoding'

                    def initialize(data = nil)
                        super('image')

                        self.text = data
                    end
                end

                class Integer < XFA::NamedTemplateElement
                    def initialize(int = nil)
                        super('integer')

                        self.text = int
                    end
                end

                class Text < XFA::NamedTemplateElement
                    xfa_attribute 'maxChars'
                    xfa_attribute 'rid'

                    def initialize(text = "")
                        super('text')

                        self.text = text
                    end
                end

                class Time < XFA::NamedTemplateElement
                    def initialize(time = nil)
                        super('time')

                        self.text = time
                    end
                end

                class Extras < XFA::NamedTemplateElement
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

                class Speak < XFA::TemplateElement
                    xfa_attribute 'disable'
                    xfa_attribute 'priority'
                    xfa_attribute 'rid'

                    def initialize(text = "")
                        super('speak')

                        self.text = text
                    end
                end

                class ToolTip < XFA::TemplateElement
                    xfa_attribute 'rid'

                    def initialize(text = "")
                        super('toolTip')

                        self.text = text
                    end
                end

                class Assist < XFA::TemplateElement
                    xfa_attribute 'role'

                    xfa_node 'speak', Template::Speak, 0..1
                    xfa_node 'toolTip', Template::ToolTip, 0..1

                    def initialize
                        super('assist')
                    end
                end

                class Picture < XFA::TemplateElement
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

                class Bookend < XFA::TemplateElement
                    xfa_attribute 'leader'
                    xfa_attribute 'trailer'

                    def initialize
                        super('bookend')
                    end
                end

                class Color < XFA::TemplateElement
                    xfa_attribute 'cSpace'
                    xfa_attribute 'value'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('color')

                        self.cSpace = "SRGB"
                    end
                end

                class Corner < XFA::TemplateElement
                    xfa_attribute 'inverted'
                    xfa_attribute 'join'
                    xfa_attribute 'presence'
                    xfa_attribute 'radius'
                    xfa_attribute 'stroke'
                    xfa_attribute 'thickness'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('corner')
                    end
                end

                class Edge < XFA::TemplateElement
                    xfa_attribute 'cap'
                    xfa_attribute 'presence'
                    xfa_attribute 'stroke'
                    xfa_attribute 'thickness'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('edge')
                    end
                end

                class Linear < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('linear')
                    end
                end

                class Pattern < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('pattern')
                    end
                end

                class Radial < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('radial')
                    end
                end

                class Solid < XFA::TemplateElement
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('solid')
                    end
                end

                class Stipple < XFA::TemplateElement
                    xfa_attribute 'rate'

                    xfa_node 'color', Template::Color, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('stipple')
                    end
                end

                class Fill < XFA::TemplateElement
                    xfa_attribute 'presence'

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

                class Margin < XFA::TemplateElement
                    xfa_attribute 'bottomInset'
                    xfa_attribute 'leftInset'
                    xfa_attribute 'rightInset'
                    xfa_attribute 'topInset'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('margin')
                    end
                end

                class Border < XFA::TemplateElement
                    xfa_attribute 'break'
                    xfa_attribute 'hand'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'

                    xfa_node 'corner', Template::Corner, 0..4
                    xfa_node 'edge', Template::Edge, 0..4
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'fill', Template::Fill, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('border')
                    end
                end

                class Break < XFA::TemplateElement
                    xfa_attribute 'after'
                    xfa_attribute 'afterTarget'
                    xfa_attribute 'before'
                    xfa_attribute 'beforeTarget'
                    xfa_attribute 'bookendLeader'
                    xfa_attribute 'bookendTrailer'
                    xfa_attribute 'overflowLeader'
                    xfa_attribute 'overflowTarget'
                    xfa_attribute 'overflowTrailer'
                    xfa_attribute 'startNew'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('break')
                    end
                end

                class Message < XFA::TemplateElement
                    xfa_node 'text', Template::Text

                    def initialize
                        super('message')
                    end
                end

                class Script < XFA::NamedTemplateElement
                    xfa_attribute 'binding'
                    xfa_attribute 'contentType'
                    xfa_attribute 'runAt'

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

                class Calculate < XFA::TemplateElement
                    xfa_attribute 'override'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'message', Template::Message, 0..1
                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('calculate')
                    end
                end

                class Desc < XFA::TemplateElement
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

                class Keep < XFA::TemplateElement
                    xfa_attribute 'intact'
                    xfa_attribute 'next'
                    xfa_attribute 'previous'

                    xfa_node 'extras', Template::Extras, 0..1

                    NONE = "none"
                    CONTENTAREA = "contentArea"
                    PAGEAREA = "pageArea"

                    def initialize
                        super('keep')
                    end
                end

                class Occur < XFA::TemplateElement
                    xfa_attribute 'initial'
                    xfa_attribute 'max'
                    xfa_attribute 'min'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('occur')
                    end
                end

                class Overflow < XFA::TemplateElement
                    xfa_attribute 'leader'
                    xfa_attribute 'target'
                    xfa_attribute 'trailer'

                    def initialize
                        super('overflow')
                    end
                end

                class Medium < XFA::TemplateElement
                    xfa_attribute 'imagingBBox'
                    xfa_attribute 'long'
                    xfa_attribute 'orientation'
                    xfa_attribute 'short'
                    xfa_attribute 'stock'
                    xfa_attribute 'trayIn'
                    xfa_attribute 'trayOut'

                    def initialize
                        super('medium')
                    end
                end

                class Font < XFA::TemplateElement
                    xfa_attribute 'baselineShift'
                    xfa_attribute 'fontHorizontalScale'
                    xfa_attribute 'fontVerticalScale'
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
                    xfa_attribute 'weight'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'fill', Template::Fill, 0..1

                    def initialize
                        super('font')
                    end
                end

                class Hyphenation < XFA::TemplateElement
                    xfa_attribute 'excludeAllCaps'
                    xfa_attribute 'excludeInitialCap'
                    xfa_attribute 'hyphenate'
                    xfa_attribute 'pushCharacterCount'
                    xfa_attribute 'remainCharacterCount'
                    xfa_attribute 'wordCharacterCount'

                    def initialize
                        super('hyphenation')
                    end
                end

                class Para < XFA::TemplateElement
                    xfa_attribute 'hAlign'
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
                    xfa_attribute 'vAlign'
                    xfa_attribute 'widows'

                    xfa_node 'hyphenation', Template::Hyphenation, 0..1

                    def initialize
                        super('para')
                    end
                end

                class Arc < XFA::TemplateElement
                    xfa_attribute 'circular'
                    xfa_attribute 'hand'
                    xfa_attribute 'startAngle'
                    xfa_attribute 'sweepAngle'

                    xfa_node 'edge', Template::Edge, 0..1
                    xfa_node 'fill', Template::Fill, 0..1

                    def initialize
                        super('arc')
                    end
                end

                class Line < XFA::TemplateElement
                    xfa_attribute 'hand'
                    xfa_attribute 'slope'

                    xfa_node 'edge', Template::Edge, 0..1

                    def initialize
                        super('line')
                    end
                end

                class Rectangle < XFA::TemplateElement
                    xfa_attribute 'hand'

                    xfa_node 'corner', Template::Corner, 0..4
                    xfa_node 'edge', Template::Edge, 0..4
                    xfa_node 'fill', Template::Fill, 0..4

                    def initialize
                        super('rectangle')
                    end
                end

                class Value < XFA::TemplateElement
                    xfa_attribute 'override'
                    xfa_attribute 'relevant'

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

                class Caption < XFA::TemplateElement
                    xfa_attribute 'placement'
                    xfa_attribute 'presence'
                    xfa_attribute 'reserve'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'font', Template::Font, 0..1
                    xfa_node 'margin', Template::Margin, 0..1
                    xfa_node 'para', Template::Para, 0..1
                    xfa_node 'value', Template::Value, 0..1

                    def initialize
                        super('caption')
                    end
                end

                class Traverse < XFA::TemplateElement
                    xfa_attribute 'operation'
                    xfa_attribute 'ref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('traverse')
                    end
                end

                class Traversal < XFA::TemplateElement
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'traverse', Template::Traverse

                    def initialize
                        super('traversal')
                    end
                end

                class Certificate < XFA::NamedTemplateElement
                    def initialize(b64data = nil)
                        super('certificate')

                        self.text = b64data
                    end
                end

                class Encrypt < XFA::TemplateElement
                    xfa_node 'certificate', Template::Certificate, 0..1

                    def initialize
                        super('encrypt')
                    end
                end

                class Barcode < XFA::TemplateElement
                    xfa_attribute 'charEncoding'
                    xfa_attribute 'checksum'
                    xfa_attribute 'dataColumnCount'
                    xfa_attribute 'dataLength'
                    xfa_attribute 'dataPrep'
                    xfa_attribute 'dataRowCount'
                    xfa_attribute 'endChar'
                    xfa_attribute 'errorConnectionLevel'
                    xfa_attribute 'moduleHeight'
                    xfa_attribute 'moduleWidth'
                    xfa_attribute 'printCheckDigit'
                    xfa_attribute 'rowColumnRatio'
                    xfa_attribute 'startChar'
                    xfa_attribute 'textLocation'
                    xfa_attribute 'truncate'
                    xfa_attribute 'type'
                    xfa_attribute 'upsMode'
                    xfa_attribute 'wideNarrowRatio'

                    xfa_node 'encrypt', Template::Encrypt, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('barcode')
                    end
                end

                class Button < XFA::TemplateElement
                    xfa_attribute 'highlight'

                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('button')
                    end
                end

                class CheckButton < XFA::TemplateElement
                    xfa_attribute 'mark'
                    xfa_attribute 'shape'
                    xfa_attribute 'size'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('checkButton')
                    end
                end

                class ChoiceList < XFA::TemplateElement
                    xfa_attribute 'commitOn'
                    xfa_attribute 'open'
                    xfa_attribute 'textEntry'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('choiceList')
                    end
                end

                class Comb < XFA::TemplateElement
                    xfa_attribute 'numberOfCells'

                    def initialize
                        super('comb')
                    end
                end

                class DateTimeEdit < XFA::TemplateElement
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'picker'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'comb', Template::Comb, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('dateTimeEdit')
                    end
                end

                class DefaultUI < XFA::TemplateElement
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('defaultUi')
                    end
                end

                class ImageEdit < XFA::TemplateElement
                    xfa_attribute 'data'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('imageEdit')
                    end
                end

                class NumericEdit < XFA::TemplateElement
                    xfa_attribute 'hScrollPolicy'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'comb', Template::Comb, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('numericEdit')
                    end
                end

                class PasswordEdit < XFA::TemplateElement
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'passwordChar'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('passwordEdit')
                    end
                end

                class AppearanceFilter < XFA::TemplateElement
                    xfa_attribute 'type'

                    def initialize(name = "")
                        super('appearanceFilter')

                        self.text = name
                    end
                end

                class Issuers < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'certificate', Template::Certificate

                    def initialize
                        super('issuers')
                    end
                end

                class KeyUsage < XFA::TemplateElement
                    xfa_attribute 'crlSign'
                    xfa_attribute 'dataEncipherment'
                    xfa_attribute 'decipherOnly'
                    xfa_attribute 'digitalSignature'
                    xfa_attribute 'encipherOnly'
                    xfa_attribute 'keyAgreement'
                    xfa_attribute 'keyCertSign'
                    xfa_attribute 'keyEncipherment'
                    xfa_attribute 'nonRepudiation'
                    xfa_attribute 'type'

                    def initialize
                        super('keyUsage')
                    end
                end

                class OID < XFA::NamedTemplateElement
                    def initialize(oid = "")
                        super('oid')

                        self.text = oid
                    end
                end

                class OIDs < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'oid', Template::OID

                    def initialize
                        super('oids')
                    end
                end

                class Signing < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'certificate', Template::Certificate

                    def initialize
                        super('signing')
                    end
                end

                class SubjectDN < XFA::NamedTemplateElement
                    xfa_attribute 'delimiter'

                    def initialize(data = "")
                        super('subjectDN')

                        self.text = data
                    end
                end

                class SubjectDNs < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'subjectDN', Template::SubjectDN, 0..1

                    def initialize
                        super('subjectDNs')
                    end
                end

                class Certificates < XFA::TemplateElement
                    xfa_attribute 'credentialServerPolicy'
                    xfa_attribute 'url'
                    xfa_attribute 'urlPolicy'

                    xfa_node 'issuers', Template::Issuers, 0..1
                    xfa_node 'keyUsage', Template::KeyUsage, 0..1
                    xfa_node 'oids', Template::OIDs, 0..1
                    xfa_node 'signing', Template::Signing, 0..1
                    xfa_node 'subjectDNs', Template::SubjectDNs, 0..1

                    def initialize
                        super('certificates')
                    end
                end

                class DigestMethod < XFA::TemplateElement
                    def initialize(method = "")
                        super('digestMethod')

                        self.text = method
                    end
                end

                class DigestMethods < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'digestMethod', Template::DigestMethod

                    def initialize
                        super('digestMethods')
                    end
                end

                class Encoding < XFA::TemplateElement
                    def initialize(encoding = "")
                        super('encoding')

                        self.text = encoding
                    end
                end

                class Encodings < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'encoding', Template::Encoding

                    def initialize
                        super('encodings')
                    end
                end

                class Handler < XFA::TemplateElement
                    xfa_attribute 'type'

                    def initialize(handler = "")
                        super('handler')

                        self.text = handler
                    end
                end

                class LockDocument < XFA::TemplateElement
                    xfa_attribute 'type'

                    def initialize(lock = "default")
                        super('lockDocument')

                        self.text = lock
                    end
                end

                class MDP < XFA::TemplateElement
                    xfa_attribute 'permissions'
                    xfa_attribute 'signatureType'

                    def initialize
                        super('mdp')
                    end
                end

                class Reason < XFA::NamedTemplateElement
                    def initialize(reason = "")
                        super('reason')

                        self.text = reason
                    end
                end

                class Reasons < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'reason', Template::Reason

                    def initialize
                        super('reasons')
                    end
                end

                class TimeStamp < XFA::TemplateElement
                    xfa_attribute 'server'
                    xfa_attribute 'type'

                    def initialize
                        super('timeStamp')
                    end
                end

                class Filter < XFA::NamedTemplateElement
                    xfa_attribute 'addRevocationInfo'
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

                class Ref < XFA::TemplateElement
                    def initialize(somexpr = nil)
                        super('ref')

                        self.text = somexpr
                    end
                end

                class Manifest < XFA::NamedTemplateElement
                    xfa_attribute 'action'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'ref', Template::Ref, 0..1

                    def initialize
                        super('manifest')
                    end
                end

                class Signature < XFA::TemplateElement
                    xfa_attribute 'type'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'filter', Template::Filter, 0..1
                    xfa_node 'manifest', Template::Manifest, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('signature')
                    end
                end

                class TextEdit < XFA::TemplateElement
                    xfa_attribute 'allowRichText'
                    xfa_attribute 'hScrollPolicy'
                    xfa_attribute 'multiLine'
                    xfa_attribute 'vScrollPolicy'

                    xfa_node 'border', Template::Border, 0..1
                    xfa_node 'comb', Template::Comb, 0..1
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'margin', Template::Margin, 0..1

                    def initialize
                        super('textEdit')
                    end
                end

                class UI < XFA::TemplateElement
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

                class Draw < XFA::NamedTemplateElement
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'h'
                    xfa_attribute 'locale'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'rotate'
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

                class Validate < XFA::TemplateElement
                    xfa_attribute 'formatTest'
                    xfa_attribute 'nullTest'
                    xfa_attribute 'scriptTest'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'message', Template::Message, 0..1
                    xfa_node 'picture', Template::Picture, 0..1
                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('validate')
                    end
                end

                class Connect < XFA::TemplateElement
                    xfa_attribute 'connection'
                    xfa_attribute 'ref'
                    xfa_attribute 'usage'

                    xfa_node 'picture', Template::Picture, 0..1

                    def initialize
                        super('connect')
                    end
                end

                class Execute < XFA::TemplateElement
                    xfa_attribute 'connection'
                    xfa_attribute 'executeType'
                    xfa_attribute 'runAt'

                    def initialize
                        super('execute')
                    end
                end

                class SignData < XFA::TemplateElement
                    xfa_attribute 'operation'
                    xfa_attribute 'ref'
                    xfa_attribute 'target'

                    xfa_node 'filter', Template::Filter, 0..1
                    xfa_node 'manifest', Template::Manifest, 0..1

                    def initialize
                        super('signData')
                    end
                end

                class Submit < XFA::TemplateElement
                    xfa_attribute 'embedPDF'
                    xfa_attribute 'format'
                    xfa_attribute 'target'
                    xfa_attribute 'textEncoding'
                    xfa_attribute 'xdpContent'

                    xfa_node 'encrypt', Template::Encrypt, 0..1
                    xfa_node 'signData', Template::SignData

                    def initialize
                        super('submit')
                    end
                end

                class Event < XFA::NamedTemplateElement
                    xfa_attribute 'activity'
                    xfa_attribute 'listen'
                    xfa_attribute 'ref'

                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'execute', Template::Execute, 0..1
                    xfa_node 'script', Template::Script, 0..1
                    xfa_node 'signData', Template::SignData, 0..1
                    xfa_node 'submit', Template::Submit, 0..1

                    def initialize
                        super('event')
                    end
                end

                class Format < XFA::TemplateElement
                    xfa_node 'extras', Template::Extras, 0..1
                    xfa_node 'picture', Template::Picture, 0..1

                    def initialize
                        super('format')
                    end
                end

                class Items < XFA::NamedTemplateElement
                    xfa_attribute 'presence'
                    xfa_attribute 'ref'
                    xfa_attribute 'save'

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

                class Field < XFA::NamedTemplateElement
                    xfa_attribute 'access'
                    xfa_attribute 'accessKey'
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'h'
                    xfa_attribute 'locale'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'rotate'
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


                class ExclGroup < XFA::NamedTemplateElement
                    xfa_attribute 'access'
                    xfa_attribute 'accessKey'
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'h'
                    xfa_attribute 'layout'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
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

                class BreakAfter < XFA::TemplateElement
                    xfa_attribute 'leader'
                    xfa_attribute 'startNew'
                    xfa_attribute 'target'
                    xfa_attribute 'targetType'
                    xfa_attribute 'trailer'

                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('breakAfter')
                    end
                end

                class BreakBefore < XFA::TemplateElement
                    xfa_attribute 'leader'
                    xfa_attribute 'startNew'
                    xfa_attribute 'target'
                    xfa_attribute 'targetType'
                    xfa_attribute 'trailer'

                    xfa_node 'script', Template::Script, 0..1

                    def initialize
                        super('breakBefore')
                    end
                end

                class Subform < XFA::NamedTemplateElement ; end
                class SubformSet < XFA::NamedTemplateElement
                    xfa_attribute 'relation'
                    xfa_attribute 'relevant'

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

                class Area < XFA::NamedTemplateElement
                    xfa_attribute 'colSpan'
                    xfa_attribute 'relevant'
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

                class ContentArea < XFA::NamedTemplateElement
                    xfa_attribute 'h'
                    xfa_attribute 'relevant'
                    xfa_attribute 'w'
                    xfa_attribute 'x'
                    xfa_attribute 'y'

                    xfa_node 'desc', Template::Desc, 0..1
                    xfa_node 'extras', Template::Extras, 0..1

                    def initialize
                        super('contentArea')
                    end
                end

                class PageArea < XFA::NamedTemplateElement
                    xfa_attribute 'blankOrNotBlank'
                    xfa_attribute 'initialNumber'
                    xfa_attribute 'numbered'
                    xfa_attribute 'oddOrEven'
                    xfa_attribute 'pagePosition'
                    xfa_attribute 'relevant'

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

                class PageSet < XFA::NamedTemplateElement
                    xfa_attribute 'relation'
                    xfa_attribute 'relevant'

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

                class Variables < XFA::TemplateElement
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

                class ExObject < XFA::NamedTemplateElement
                    xfa_attribute 'archive'
                    xfa_attribute 'classId'
                    xfa_attribute 'codeBase'
                    xfa_attribute 'codeType'

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

                class Subform < XFA::NamedTemplateElement
                    xfa_attribute 'access'
                    xfa_attribute 'allowMacro'
                    xfa_attribute 'anchorType'
                    xfa_attribute 'colSpan'
                    xfa_attribute 'columnWidths'
                    xfa_attribute 'h'
                    xfa_attribute 'layout'
                    xfa_attribute 'locale'
                    xfa_attribute 'maxH'
                    xfa_attribute 'maxW'
                    xfa_attribute 'minH'
                    xfa_attribute 'minW'
                    xfa_attribute 'presence'
                    xfa_attribute 'relevant'
                    xfa_attribute 'restoreState'
                    xfa_attribute 'scope'
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

        end
    end
end
