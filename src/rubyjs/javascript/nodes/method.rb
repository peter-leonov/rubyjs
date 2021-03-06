module RubyJS; class Compiler; class Node

  class MethodCall

    class ArgumentList
      def as_javascript
        raise unless get(:mode) == :expression
        @elements.map {|e| e.javascript }.join(", ")
      end

      def brackets?; raise end
    end

    class BlockPass
      def as_javascript
        @block.javascript
      end
    end

    def as_javascript
      if @receiver.is?(Const) and @receiver.name == 'RubyJS'
        #
        # Treat a special case.
        #
        raise unless @arguments.is?(ArgumentList)
        if self.respond_to?("plugin_#{@method_name}")
          self.send("plugin_#{@method_name}", *@arguments.elements)
        else
          raise "plugin #{@method_name} not found"
        end
      else
        @compiler.method_scope.add_method_call(@method_name)
        fmt = @receiver.brackets? ? "(%s).%s(%s)" : "%s.%s(%s)"
        fmt % [
          @receiver.javascript(:expression),
          encoder.encode_method(@method_name),
          @arguments.javascript(:expression)
        ]
      end
    end

    def plugin_attr(arg)
      raise ArgumentError unless arg.is?(SymbolLiteral)
      encoder.encode_attr(arg.value.to_s)
    end

    def plugin_inline(arg)
      raise ArgumentError unless arg.is?(StringLiteral)
      arg.string
    end

    def plugin_runtime(arg)
      raise ArgumentError unless arg.is?(SymbolLiteral)
      encoder.encode_runtime(arg.value.to_s)
    end

    def plugin_method(arg)
      raise ArgumentError unless arg.is?(SymbolLiteral)
      encoder.encode_method(arg.value.to_s)
    end

    #
    # Checks like "arg == null ? #{nil} : #{arg}" are pretty common in
    # the core of RubyJS. This is a helper "macro" to avoid typing this
    # over and over again.
    #
    def plugin_conv2ruby(arg)
      @local_scope.with_temporary_variable {|temp_var|
        tmp = encode(temp_var)
        js = arg.javascript(:expression)
        "(#{tmp}=(#{js}),#{tmp}==null ? #{encoder.encode_nil} : #{tmp})" 
      }
    end
  end

  class Scope
    def as_javascript
      @body.javascript
    end

    def brackets?; raise end
    def compound?; true end
  end

  class DefineMethod
    def as_javascript
      raise if get(:mode) == :expression

      args, opt, body = nil, nil, nil

      self_variable = SelfVariable.new
      @local_scope.with_temporary_variable do |alternate_self_variable|
        set(:self => self_variable, :alternate_self => alternate_self_variable) do
          args = @arguments.javascript_arglist
          opt = @arguments.javascript_optional

          #
          # We have to generate the body before generating
          # the variable declarations, as within the body temporary
          # variables might be allocated.
          #
          body = @body.javascript(:last)

          #
          # We only have to set the alternate self variable if it was
          # used somewhere (within an iterator)
          #
          if alternate_self_variable.used?
            body = encode(alternate_self_variable) + "=" + encode_self() + ";" + body 
          end

        end
      end

      "function(#{args}){\n" + variable_declaration() + (opt ? opt + ";" : "") + body + "}"
    end

    def variable_declaration
      arr = (@local_scope.variables.values - @arguments.variables).
        select {|var| var.used? }.map {|var| encode(var) } 
      arr += (@local_scope.temporary_variables.values).
        select {|var| var.used? }.map {|var| encode(var) }

      if arr.empty?
        ""
      else
        "var " + arr.join(',') + ";"
      end
    end

    def brackets?; raise end
  end

  class MethodArguments
    def javascript_arglist
      args = @arguments.map {|var| encode(var) }
      if @block and not @catch_all
        args += ["_", encode(@block)]
      end
      args.join(", ")
    end

    def javascript_optional
      return nil unless @optional

      "switch(arguments.length) {\n" + 
      @optional.statements.each_with_index.map {|opt, i|
        "case #{self.min_arity+i}: #{opt.javascript(:statement)};"
      }.join("\n") + "}\n"
    end

    def brackets?; raise end
  end

  class Super
    def as_javascript
      @compiler.method_scope.add_super_call
      raise
    end
  end

  class ZSuper
    def as_javascript
      @compiler.method_scope.add_super_call
      raise
    end
  end

  class AttrAssign
    def as_javascript
      @compiler.method_scope.add_method_call(@method_name)
      raise
    end
  end

  class Return
    #
    # We don't want "return" to be generate within Node#javascript.
    #
    def compound?; true end

    def as_javascript
      # FIXME: implement as expression
      raise if get(:mode) == :expression
      "return (#{@argument.javascript(:expression)})"
    end
  end

end; end; end # class Node; class Compiler; module RubyJS
