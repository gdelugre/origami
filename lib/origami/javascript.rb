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

    begin
        require 'v8'

        class PDF

            module JavaScript
                module Platforms
                    WINDOWS = "WIN"
                    UNIX = "UNIX"
                    MAC = "MAC"
                end

                module Viewers
                    ADOBE_READER = "Reader"
                end

                class Error < Origami::Error; end

                class MissingArgError < Error
                    def initialize; super("Missing required argument.") end
                end

                class TypeError < Error
                    def initialize; super("Incorrect argument type.") end
                end

                class InvalidArgsError < Error
                    def initialize; super("Incorrect arguments.") end
                end

                class NotAllowedError < Error
                    def initialize; super("Security settings prevent access to this property or method.") end
                end

                class HelpError < Error
                    def initialize; super("Help") end
                end

                class GeneralError < Error
                    def initialize; super("Operation failed.") end
                end

                class Arg
                    attr_reader :name, :type, :required, :default

                    def initialize(declare = {})
                        @name = declare[:name]
                        @type = declare[:type]
                        @required = declare[:required]
                        @default = declare[:default]
                    end

                    def self.[](declare = {})
                        self.new(declare)
                    end

                    def self.inspect(obj)
                        case obj
                        when V8::Function then "function #{obj.name}"
                        when V8::Array then obj.to_a.inspect
                        when V8::Object
                            "{#{obj.to_a.map{|k,v| "#{k}:#{Arg.inspect(v)}"}.join(', ')}}"
                        else
                            obj.inspect
                        end
                    end
                end

                class AcrobatObject
                    def initialize(engine)
                        @engine = engine
                    end

                    def self.check_method_args(args, def_args)
                        if args.first.is_a?(V8::Object)
                            check_method_named_args(args.first, def_args)
                        else
                            check_method_ordered_args(args, def_args)
                        end
                    end

                    def self.check_method_named_args(object, def_args)
                        members = object.entries.map {|k, _| k}
                        argv = []
                        def_args.each do |def_arg|
                            raise MissingArgError if def_arg.required and not members.include?(def_arg.name)

                            if members.include?(def_arg.name)
                                arg = object[def_arg.name]
                                raise TypeError if def_arg.type and not arg.is_a?(def_arg.type)
                            else
                                arg = def_arg.default
                            end

                            argv.push(arg)
                        end

                        argv
                    end
                    private_class_method :check_method_named_args

                    def self.check_method_ordered_args(args, def_args)
                        def_args.each_with_index do |def_arg, index|
                            raise MissingArgError if def_arg.required and index >= args.length
                            raise TypeError if def_arg.type and not args[index].is_a?(def_arg.type)

                            args.push(def_arg.default) if index >= args.length
                        end

                        args
                    end
                    private_class_method :check_method_ordered_args

                    def self.acro_method(name, *def_args, &b)
                        define_method(name) do |*args|
                            if @engine.options[:log_method_calls]
                                @engine.options[:console].puts(
                                    "LOG: #{self.class}.#{name}(#{args.map{|arg| Arg.inspect(arg)}.join(',')})"
                                )
                            end

                            args = AcrobatObject.check_method_args(args, def_args)
                            self.instance_exec(*args, &b) if b
                        end
                    end

                    def self.acro_method_protected(name, *def_args, &b)
                        define_method(name) do |*args|
                            if @engine.options[:log_method_calls]
                                @engine.options[:console].puts(
                                    "LOG: #{self.class}.#{name}(#{args.map{|arg| arg.inspect}.join(',')})"
                                )
                            end

                            unless @engine.privileged?
                                raise NotAllowedError, "Security settings prevent access to this property or method."
                            end

                            args = AcrobatObject.check_method_args(args, def_args)
                            self.instance_exec(*args, &b) if b
                        end
                    end

                    def to_s
                        "[object #{self.class.to_s.split('::').last}]"
                    end
                    alias inspect to_s
                end

                class AcroTimer < AcrobatObject
                    def initialize(engine, timeout, code, repeat)
                        @thr = Thread.start(engine, timeout, code, repeat) do
                            loop do
                                sleep(timeout / 1000.0)
                                engine.exec(code.to_s)
                                break if not repeat
                            end
                        end
                    end
                end

                class TimeOut < AcroTimer
                    def initialize(engine, timeout, code)
                        super(engine, timeout, code, false)
                    end
                end

                class Interval < AcroTimer
                    def initialize(engine, timeout, code)
                        super(engine, timeout, code, true)
                    end
                end

                class ReadStream < AcrobatObject
                    def initialize(engine, data)
                        super(engine)

                        @data = data
                    end

                    acro_method 'read', Arg[name: 'nBytes', type: Numeric, required: true] do |nBytes|
                        @data.slice!(0, nBytes).unpack("H*")[0]
                    end
                end

                class Acrohelp < AcrobatObject; end

                class Global < AcrobatObject
                    def initialize(engine)
                        super(engine)

                        @vars = {}
                    end

                    def []=(name, value)
                        @vars[name] ||= {callbacks: []}
                        @vars[name][:value] = value
                        @vars[name][:callbacks].each do |callback|
                            callback.call(value)
                        end
                    end

                    def [](name)
                        @vars[name][:value] if @vars.include?(name)
                    end

                    acro_method 'setPersistent',
                        Arg[name: 'cVariable', required: true],
                        Arg[name: 'bPersist', required: true] do |cVariable, _bPersist|

                        raise GeneralError unless @vars.include?(cVariable)
                    end

                    acro_method 'subscribe',
                        Arg[name: 'cVariable', required: true],
                        Arg[name: 'fCallback', type: V8::Function, require: true] do |cVariable, fCallback|

                        if @vars.include?(cVariable)
                            @vars[cVariable][:callbacks].push(fCallback)
                            fCallback.call(@vars[cVariable][:value])
                        end
                    end
                end

                class Doc < AcrobatObject
                    attr_reader :info
                    attr_accessor :disclosed
                    attr_reader :hidden

                    attr_reader :app, :acrohelp, :global, :console, :util

                    class Info < AcrobatObject
                        def initialize(engine, doc)
                            super(engine)

                            @doc = doc
                        end

                        def title; @doc.title.to_s end
                        def author; @doc.author.to_s end
                        def subject; @doc.subject.to_s end
                        def keywords; @doc.keywords.to_s end
                        def creator; @doc.creator.to_s end
                        def creationDate; @doc.creation_date.to_s end
                        def modDate; @doc.mod_date.to_s end
                    end

                    def initialize(*args)
                        engine, pdf = args # XXX: Bypass therubyracer bug #238. Temporary.
                        super(engine)

                        @pdf = pdf
                        @disclosed = false
                        @hidden = false
                        @info = Info.new(@engine, pdf)

                        @app = JavaScript::App.new(@engine)
                        @acrohelp = JavaScript::Acrohelp.new(@engine)
                        @global = JavaScript::Global.new(@engine)
                        @console = JavaScript::Console.new(@engine)
                        @util = JavaScript::Util.new(@engine)
                    end

                    ### PROPERTIES ###

                    def numFields
                        fields = @pdf.fields

                        fields.size
                    end

                    def numPages; @pdf.pages.size end

                    def title; @info.title end
                    def author; @info.author end
                    def subject; @info.subject end
                    def keywords; @info.keywords end
                    def creator; @info.creator end
                    def creationDate; @info.creationDate end
                    def modDate; @info.modDate end

                    def metadata
                        meta = @pdf.Catalog.Metadata

                        (meta.data if meta.is_a?(Stream)).to_s
                    end

                    def filesize; @pdf.original_filesize end
                    def path; @pdf.original_filename.to_s end
                    def documentFileName; File.basename(self.path) end
                    def URL; "file://#{self.path}" end
                    def baseURL; '' end

                    def dataObjects
                        data_objs = []
                        @pdf.each_attachment do |name, file_desc|
                            if file_desc and file_desc.EF and (f = file_desc.EF.F)
                                data_objs.push Data.new(@engine, name, f.data.size) if f.is_a?(Stream)
                            end
                        end

                        data_objs
                    end

                    ### METHODS ###

                    acro_method 'closeDoc'

                    acro_method 'getDataObject',
                        Arg[name: 'cName', type: ::String, required: true] do |cName|

                        file_desc = @pdf.resolve_name(Names::EMBEDDED_FILES, cName)

                        if file_desc and file_desc.EF and (f = file_desc.EF.F)
                            Data.new(@engine, cName, f.data.size) if f.is_a?(Stream)
                        else
                            raise TypeError
                        end
                    end

                    acro_method 'getDataObjectContents',
                        Arg[name: 'cName', type: ::String, required: true],
                        Arg[name: 'bAllowAuth', default: false] do |cName, _bAllowAuth|

                        file_desc = @pdf.resolve_name(Names::EMBEDDED_FILES, cName)

                        if file_desc and file_desc.EF and (f = file_desc.EF.F)
                            ReadStream.new(@engine, f.data) if f.is_a?(Stream)
                        else
                            raise TypeError
                        end
                    end

                    acro_method 'exportDataObject',
                        Arg[name: 'cName', type: ::String, required: true],
                        Arg[name: 'cDIPath' ],
                        Arg[name: 'bAllowAuth'],
                        Arg[name: 'nLaunch'] do |cName, _cDIPath, _bAllowAuth, _nLaunch|

                        file_desc = @pdf.resolve_name(Names::EMBEDDED_FILES, cName)

                        if file_desc and file_desc.EF and (f = file_desc.EF.F)
                        else
                            raise TypeError
                        end

                        raise TypeError if f.nil?
                    end

                    acro_method 'getField',
                        Arg[name: 'cName', type: ::Object, required: true] do |cName|

                        field = @pdf.get_field(cName)

                        Field.new(@engine, field) if field
                    end

                    acro_method 'getNthFieldName',
                        Arg[name: 'nIndex', type: ::Object, required: true] do |nIndex|

                        nIndex =
                            case nIndex
                            when false then 0
                            when true then 1
                            else
                                @engine.parseInt.call(nIndex)
                            end

                        raise TypeError if (nIndex.is_a?(Float) and nIndex.nan?) or nIndex < 0
                        fields = @pdf.fields

                        if fields and nIndex <= fields.size - 1
                            Field.new(@engine, fields.take(nIndex + 1).last).name.to_s
                        else
                            ""
                        end
                    end
                end

                class App < AcrobatObject

                    def platform; @engine.options[:platform] end
                    def viewerType; @engine.options[:viewerType] end
                    def viewerVariation; @engine.options[:viewerVariation] end
                    def viewerVersion; @engine.options[:viewerVersion] end

                    def activeDocs; [] end

                    ### METHODS ###

                    acro_method 'setInterval',
                        Arg[name: 'cExpr', required: true],
                        Arg[name: 'nMilliseconds', type: Numeric, required: true] do |cExpr, nMilliseconds|

                        Interval.new(@engine, nMilliseconds, cExpr)
                    end

                    acro_method 'setTimeOut',
                        Arg[name: 'cExpr', required: true],
                        Arg[name: 'nMilliseconds', type: Numeric, required: true] do |cExpr, nMilliseconds|

                        TimeOut.new(@engine, nMilliseconds, cExpr)
                    end

                    acro_method 'clearInterval',
                        Arg[name: 'oInterval', type: Interval, required: true] do |oInterval|

                        oInterval.instance_variable_get(:@thr).terminate
                        nil
                    end

                    acro_method 'clearTimeOut',
                        Arg[name: 'oInterval', type: TimeOut, required: true] do |oInterval|

                        oInterval.instance_variable_get(:@thr).terminate
                        nil
                    end

                    acro_method_protected 'addMenuItem'
                    acro_method_protected 'addSubMenu'
                    acro_method           'addToolButton'
                    acro_method_protected 'beginPriv'
                    acro_method           'beep'
                    acro_method_protected 'browseForDoc'
                    acro_method_protected 'endPriv'
                end

                class Console < AcrobatObject
                    def println(*args)
                        raise MissingArgError unless args.length > 0

                        @engine.options[:console].puts(args.first.to_s)
                    end

                    acro_method 'show'
                    acro_method 'clear'
                    acro_method 'hide'
                end

                class Util < AcrobatObject
                    acro_method 'streamFromString',
                        Arg[name: 'cString', type: ::Object, required: true],
                        Arg[name: 'cCharset', type: ::Object, default: 'utf-8'] do |cString, _cCharset|

                        ReadStream.new(@engine, cString.to_s)
                    end

                    acro_method 'stringFromStream',
                        Arg[name: 'oStream', type: ReadStream, required: true],
                        Arg[name: 'cCharset', type: ::Object, default: 'utf-8'] do |oStream, _cCharset|

                        oStream.instance_variable_get(:@data).dup
                    end
                end

                class Field < AcrobatObject
                    def initialize(engine, field)
                        super(engine)

                        @field = field
                    end

                    def doc; Doc.new(@field.document) end
                    def name
                        (@field.T.value if @field.has_key?(:T)).to_s
                    end

                    def value
                        @field.V.value if @field.has_key?(:V)
                    end

                    def valueAsString
                        self.value.to_s
                    end

                    def type
                        return '' unless @field.key?(:FT)

                        type_name =
                        case @field.FT.value
                        when PDF::Field::Type::BUTTON
                            button_type

                        when PDF::Field::Type::TEXT then 'text'
                        when PDF::Field::Type::SIGNATURE then 'signature'
                        when PDF::Field::Type::CHOICE
                            choice_type
                        end

                        type_name.to_s
                    end

                    private

                    def button_type
                        return if @field.key?(:Ff) and not @field.Ff.is_a?(Integer)

                        flags = @field.Ff.to_i

                        if (flags & Annotation::Widget::Button::Flags::PUSHBUTTON) != 0
                            'button'
                        elsif (flags & Annotation::Widget::Button::Flags::RADIO) != 0
                            'radiobox'
                        else
                            'checkbox'
                        end
                    end

                    def choice_type
                        return if @field.key?(:Ff) and not @field.Ff.is_a?(Integer)

                        if (@field.Ff.to_i & Annotation::Widget::Choice::Flags::COMBO) != 0
                            'combobox'
                        else
                            'listbox'
                        end
                    end
                end

                class Data < AcrobatObject
                    attr_reader :name, :path, :size
                    attr_reader :creationDate, :modDate
                    attr_reader :description, :MIMEType

                    def initialize(engine, name, size, **metadata)
                        super(engine)

                        @name,  @size = name, size

                        @path, @creationDate, @modDate,
                        @description, @MIMEType = metadata.values_at(:path, :creationDate, :modDate, :description, :MIMEType)
                    end
                end
            end

            class JavaScript::EngineError < Origami::Error; end

            class JavaScript::Engine
                attr_reader :doc
                attr_reader :context
                attr_reader :options
                attr_reader :privileged_mode
                attr_reader :parseInt

                def initialize(pdf)
                    @options =
                    {
                        formsVersion: 11.008,
                        viewerVersion: 11.008,
                        viewerType: JavaScript::Viewers::ADOBE_READER,
                        viewerVariation: JavaScript::Viewers::ADOBE_READER,
                        platform: JavaScript::Platforms::WINDOWS,
                        console: STDOUT,
                        log_method_calls: false,
                        privileged_mode: false
                    }

                    @doc = JavaScript::Doc.new(self, pdf)
                    @context = V8::Context.new(with: @doc)
                    @privileged_mode = @options[:privileged_mode]

                    @parseInt = V8::Context.new['parseInt']
                    @hooks = {}
                end

                #
                # Returns true if the engine is set to execute in privileged mode.
                # Allows execution of security protected methods.
                #
                def privileged?
                    @privileged_mode
                end

                #
                # Evaluates a JavaScript code in the current context.
                #
                def exec(script)
                    @context.eval(script)
                end

                #
                # Set a hook on a JavaScript method.
                #
                def hook(name, &callback)
                    ns = name.split('.')
                    previous = @context

                    ns.each do |n|
                        raise JavaScript::EngineError, "#{name} does not exist" if previous.nil?
                        previous = previous[n]
                    end

                    case previous
                    when V8::Function, UnboundMethod, nil then
                        @context[name] = lambda do |*args|
                            callback[previous, *args]
                        end

                        @hooks[name] = [previous, callback]
                    else
                        raise JavaScript::EngineError, "#{name} is not a function"
                    end
                end

                #
                # Removes an existing hook on a JavaScript method.
                #
                def unhook(name)
                    @context[name] = @hooks[name][0] if @hooks.has_key?(name)
                end

                #
                # Returns an Hash of all defined members in specified object name.
                #
                def members(obj)
                    members = {}
                    list = @context.eval <<-JS
                        (function(base) {
                            var members = [];
                            for (var i in base) members.push([i, base[i]]);
                            return members;
                        })(#{obj})
                    JS

                    list.each do |var|
                        members[var[0]] = var[1]
                    end

                    members
                end

                #
                # Returns all members in the global scope.
                #
                def scope
                    members('this')
                end

                #
                # Binds the V8 remote debugging agent on the specified TCP _port_.
                #
                def enable_debugger(port = 5858)
                    V8::C::Debug.EnableAgent("Origami", port)
                end

                def debugger_break
                    exec 'debugger'
                end
            end
        end

        module String
            #
            # Evaluates the current String as JavaScript.
            #
            def eval_js
                self.document.eval_js(self.value)
            end
        end

        class Stream
            #
            # Evaluates the current Stream as JavaScript.
            #
            def eval_js
                self.document.eval_js(self.data)
            end
        end

        class PDF
            #
            # Executes a JavaScript script in the current document context.
            #
            def eval_js(code)
                js_engine.exec(code)
            end

            #
            # Returns the JavaScript engine (if JavaScript support is present).
            #
            def js_engine
                @js_engine ||= PDF::JavaScript::Engine.new(self)
            end
        end

    rescue LoadError
        #
        # V8 unavailable.
        #
    end
end
