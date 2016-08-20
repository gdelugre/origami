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
        # Attachs an embedded file to the PDF.
        # _path_:: The path to the file to attach.
        # _register_:: Whether the file shall be registered in the name directory.
        # _name_:: The embedded file name of the attachment.
        # _filter_:: The stream filter used to store the file contents.
        #
        def attach_file(path, register: true, name: nil, filter: :FlateDecode)

            if path.is_a? FileSpec
                filespec = path
                name ||= ''
            else
                if path.respond_to?(:read)
                    data = path.read.force_encoding('binary')
                    name ||= ''
                else
                    data = File.binread(File.expand_path(path))
                    name ||= File.basename(path)
                end

                fstream = EmbeddedFileStream.new
                fstream.data = data

                fstream.Filter = filter
                filespec = FileSpec.new(:F => fstream)
            end

            fspec = FileSpec.new.setType(:Filespec).setF(name.dup).setEF(filespec)

            self.register(
                Names::EMBEDDED_FILES,
                name.dup,
                fspec
            ) if register

            fspec
        end

        #
        # Lookup embedded file in the embedded files name directory.
        #
        def get_embedded_file_by_name(name)
            resolve_name Names::EMBEDDED_FILES, name
        end

        #
        # Calls block for each named embedded file.
        #
        def each_named_embedded_file(&b)
            each_name(Names::EMBEDDED_FILES, &b)
        end
        alias each_attachment each_named_embedded_file
    end

    #
    # Class used to convert system-dependent pathes into PDF pathes.
    # PDF path specification offers a single form for representing file pathes over operating systems.
    #
    class Filename

        class << self
            #
            # Converts UNIX file path into PDF file path.
            #
            def Unix(file)
                LiteralString.new(file)
            end

            #
            # Converts MacOS file path into PDF file path.
            #
            def Mac(file)
                LiteralString.new("/" + file.tr(":", "/"))
            end

            #
            # Converts Windows file path into PDF file path.
            #
            def DOS(file)
                path = ""
                # Absolute vs relative path
                if file.include? ":"
                    path << "/"
                    file.sub!(":","")
                end

                file.tr!("\\", "/")
                LiteralString.new(path + file)
            end
        end
    end

    #
    # Class representing  a file specification.
    # File specifications can be used to reference external files, as well as embedded files and URIs.
    #
    class FileSpec < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :FileSpec
        field   :FS,            :Type => Name, :Default => :URL
        field   :F,             :Type => [ String, Stream ]
        field   :UF,            :Type => String
        field   :DOS,           :Type => String
        field   :Mac,           :Type => String
        field   :Unix,          :Type => String
        field   :ID,            :Type => Array
        field   :V,             :Type => Boolean, :Default => false, :Version => "1.2"
        field   :EF,            :Type => Dictionary, :Version => "1.3"
        field   :RF,            :Type => Dictionary, :Version => "1.3"
        field   :Desc,          :Type => String, :Version => "1.6"
        field   :CI,            :Type => Dictionary, :Version => "1.7"
        field   :Thumb,         :Type => Stream, :Version => "1.7", :ExtensionLevel => 3
    end

    #
    # Class representing a Uniform Resource Locator (URL)
    #
    class URL < FileSpec
        field   :Type,        :Type => Name, :Default => :URL, :Required => true

        def initialize(url)
            super(:F => url)
        end
    end

    #
    # A class representing a file outside the current PDF file.
    #
    class ExternalFile < FileSpec
        field   :Type,        :Type => Name, :Default => :FileSpec #, :Required => true

        #
        # Creates a new external file specification.
        # _dos_:: The Windows path to this file.
        # _mac_:: The MacOS path to this file.
        # _unix_:: The UNIX path to this file.
        #
        def initialize(dos, mac: "", unix: "")
            if not mac.empty? or not unix.empty?
                super(:DOS => Filename.DOS(dos), :Mac => Filename.Mac(mac), :Unix => Filename.Unix(unix))
            else
                super(:F => dos)
            end
        end
    end

    #
    # Class representing parameters for a EmbeddedFileStream.
    #
    class EmbeddedFileParameters < Dictionary
        include StandardObject

        field   :Size,          :Type => Integer
        field   :CreationDate,  :Type => String
        field   :ModDate,       :Type => String
        field   :Mac,           :Type => Dictionary
        field   :Checksum,      :Type => String
    end

    #
    # Class representing the data of an embedded file.
    #
    class EmbeddedFileStream < Stream
        include StandardObject

        field   :Type,          :Type => Name, :Default => :EmbeddedFile
        field   :Subtype,       :Type => Name
        field   :Params,        :Type => EmbeddedFileParameters
    end

end
