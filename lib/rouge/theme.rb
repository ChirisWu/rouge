module Rouge
  class Theme
    class Style < Hash
      def initialize(theme, hsh={})
        super()
        @theme = theme
        merge!(hsh)
      end

      def render(selector, &b)
        return enum_for(:render, selector).to_a.join("\n") unless b

        return if empty?

        yield "#{selector} {"
        yield "  color: #{@theme.palette(self[:fg])};" if self[:fg]
        yield "  background-color: #{@theme.palette(self[:bg])};" if self[:bg]
        yield "  font-weight: bold;" if self[:bold]
        yield "  font-style: italic;" if self[:italic]
        yield "  text-decoration: underline;" if self[:underline]

        (self[:rules] || []).each do |rule|
          yield "  #{rule};"
        end

        yield "}"
      end

    end

    def styles
      @styles ||= self.class.styles.dup
    end

    @palette = {}
    def self.palette(arg={})
      @palette ||= superclass.palette.dup

      if arg.is_a? Hash
        @palette.merge! arg
        @palette
      else
        case arg
        when /#[0-9a-f]+/i
          arg
        else
          @palette[arg] or raise "not in palette: #{arg.inspect}"
        end
      end
    end

    class << self
      def styles
        @styles ||= {}
      end

      def style(*tokens)
        style = tokens.last.is_a?(Hash) ? tokens.pop : {}

        style = Style.new(self, style)

        tokens.each do |tok|
          styles[tok.to_s] = style
        end
      end

      def name(n=nil)
        return @name if n.nil?

        @name = n.to_s
        Theme.registry[@name] = self
      end

      def find(n)
        registry[n.to_s]
      end

      def registry
        @registry ||= {}
      end
    end
  end

  class CSSTheme < Theme
    def initialize(opts={})
      @scope = opts[:scope] || '.highlight'
    end

    def render(&b)
      return enum_for(:render).to_a.join("\n") unless b

      styles.each do |tokname, style|
        style.render(css_selector(Token[tokname]), &b)
      end
    end

  private
    def css_selector(token)
      tokens = [token]
      parent = token.parent

      inflate_token(token).map do |tok|
        raise "unknown token: #{tok.inspect}" if tok.shortname.nil?

        single_css_selector(tok)
      end.join(', ')
    end

    def single_css_selector(token)
      return @scope if token == Token['Text']

      "#{@scope} .#{token.shortname}"
    end

    # yield all of the tokens that should be styled the same
    # as the given token.  Essentially this recursively all of
    # the subtokens, except those which are more specifically
    # styled.
    def inflate_token(tok, &b)
      return enum_for(:inflate_token, tok) unless block_given?

      yield tok
      tok.sub_tokens.each_value do |st|
        next if styles.include? st.name

        inflate_token(st, &b)
      end
    end
  end
end
