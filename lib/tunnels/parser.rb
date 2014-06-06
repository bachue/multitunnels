require 'http/parser'

class Parser
  attr_reader :raw

  def initialize
    @parser = Http::Parser.new
    @raw = ''
  end

  def << data
    @raw << data
    @parser << data
  rescue HTTP::Parser::Error => e
    STDERR.puts e.message
    reset
  end

  def on_complete
    @parser.on_message_complete = proc do
      yield @raw
      reset
    end
  end

  def reset
    @parser.reset!
    @raw.respond_to?(:clear) ? @raw.clear : @raw = ''
  end
end
