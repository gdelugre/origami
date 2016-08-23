=begin

    This file is part of PDF Walker, a graphical PDF file browser
    Copyright (C) 2016	Guillaume Delugré.

    PDF Walker is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    PDF Walker is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with PDF Walker.  If not, see <http://www.gnu.org/licenses/>.

=end

require 'origami'
require 'yaml'

module PDFWalker

    class Walker < Window

        class Config
            DEFAULT_CONFIG_FILE = "#{File.expand_path("~")}/.pdfwalker.conf.yml"
            DEFAULT_CONFIG =
            {
                "Debug" =>
                {
                    "Profiling" => false,
                    "ProfilingOutputDir" => "prof",
                    "Verbosity" => Origami::Parser::VERBOSE_TRACE,
                    "IgnoreFileHeader" => true
                },

                "UI" =>
                {
                    "LastOpenedDocuments" => []
                }
            }
            NLOG_RECENT_FILES = 5

            def initialize(configfile = DEFAULT_CONFIG_FILE)
                begin
                    @conf = YAML.load(File.open(configfile))
                rescue
                    @conf = DEFAULT_CONFIG
                ensure
                    @filename = configfile
                    set_missing_values
                end
            end

            def last_opened_file(filepath)
                @conf["UI"]['LastOpenedDocuments'].push(filepath).uniq!
                @conf["UI"]['LastOpenedDocuments'].delete_at(0) while @conf["UI"]['LastOpenedDocuments'].size > NLOG_RECENT_FILES

                save
            end

            def recent_files(n = NLOG_RECENT_FILES)
                @conf["UI"]['LastOpenedDocuments'].last(n).reverse
            end

            def set_profiling(bool)
                @conf["Debug"]['Profiling'] = bool
                save
            end

            def profile?
                @conf["Debug"]['Profiling']
            end

            def profile_output_dir
                @conf["Debug"]['ProfilingOutputDir']
            end

            def set_ignore_header(bool)
                @conf["Debug"]['IgnoreFileHeader'] = bool
                save
            end

            def ignore_header?
                @conf["Debug"]['IgnoreFileHeader']
            end

            def set_verbosity(level)
                @conf["Debug"]['Verbosity'] = level
                save
            end

            def verbosity
                @conf["Debug"]['Verbosity']
            end

            def save
                File.open(@filename, "w").write(@conf.to_yaml)
            end

            private

            def set_missing_values
                @conf ||= {}

                DEFAULT_CONFIG.each_key do |cat|
                    @conf[cat] = {} unless @conf.include?(cat)

                    DEFAULT_CONFIG[cat].each_pair do |key, value|
                        @conf[cat][key] = value unless @conf[cat].include?(key)
                    end
                end
            end
        end

    end
end
