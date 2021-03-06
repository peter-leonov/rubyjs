class Exception
  attr_reader :message

  def to_s
    @message
  end

  def initialize(message=nil)
    if message.nil?
      @message = self.class.name
    else
      @message = message
    end
  end

  def inspect
    "#<#{self.class.name}: #{@message}>"
  end
end

class StandardError < Exception; end
class NameError < StandardError; end
class NoMethodError < NameError; end
class RuntimeError < StandardError; end
class ArgumentError < StandardError; end
class TypeError < StandardError; end
class LocalJumpError < StandardError; end
