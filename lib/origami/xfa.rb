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

    autoload :XFA,                      "origami/xfa/xfa"

    module XDP
        autoload :Package,              "origami/xfa/package"

        module Packet
            autoload :Config,           "origami/xfa/config"
            autoload :ConnectionSet,    "origami/xfa/connectionset"
            autoload :Datasets,         "origami/xfa/datasets"
            autoload :LocaleSet,        "origami/xfa/localeset"
            autoload :PDF,              "origami/xfa/pdf"
            autoload :Signature,        "origami/xfa/signature"
            autoload :SourceSet,        "origami/xfa/sourceset"
            autoload :StyleSheet,       "origami/xfa/stylesheet"
            autoload :Template,         "origami/xfa/template"
            autoload :XDC,              "origami/xfa/xdc"
            autoload :XFDF,             "origami/xfa/xfdf"
            autoload :XMPMeta,          "origami/xfa/xmpmeta"
        end

    end

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

end
