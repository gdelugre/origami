begin
    require 'origami'
rescue LoadError
    $: << File.join(__dir__, '../../lib')
    require 'origami'
end
include Origami

require 'console.rb'
require 'readline'

OPENSSL_SUPPORT = (defined?(OpenSSL).nil?) ? 'no' : 'yes'
JAVASCRIPT_SUPPORT = (defined?(PDF::JavaScript::Engine).nil?) ? 'no' : 'yes'
DEFAULT_BANNER = "Welcome to the PDF shell (Origami release #{Origami::VERSION}) [OpenSSL: #{OPENSSL_SUPPORT}, JavaScript: #{JAVASCRIPT_SUPPORT}]\n"

def set_completion
    completionProc = proc { |input|
        bind = IRB.conf[:MAIN_CONTEXT].workspace.binding

        case input
        when /^(.*)::$/
            begin
                space = eval("Origami::#{$1}", bind)
            rescue Exception
                return []
            end

            return space.constants.reject{|const| space.const_get(const) <= Exception}

        when /^(.*).$/
            begin
                space = eval($1, bind)
            rescue
                return []
            end

            return space.public_methods
        end
    }

    if Readline.respond_to?("basic_word_break_characters=")
        Readline.basic_word_break_characters= " \t\n\"\\'`><=;|&{("
    end

    Readline.completion_append_character = nil
    Readline.completion_proc = completionProc
end

def set_prompt
    IRB.conf[:PROMPT][:PDFSH] = {
        PROMPT_C: "?>> ",
        RETURN: "%s\n",
        PROMPT_I: ">>> ",
        PROMPT_N: ">>> ",
        PROMPT_S: nil
    }

    IRB.conf[:PROMPT_MODE] = :PDFSH
    IRB.conf[:AUTO_INDENT] = true
end

# Print the shell banner.
puts DEFAULT_BANNER.green

# Import the type conversion helper routines.
TOPLEVEL_BINDING.eval("using Origami::TypeConversion")

#set_completion
set_prompt
