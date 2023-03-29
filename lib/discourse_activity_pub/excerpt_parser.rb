# frozen_string_literal: true

# TODO (future): PR discourse/discourse to support alternate excerpts

class DiscourseActivityPub::ExcerptParser < ExcerptParser
  CUSTOM_NOTE_REGEX = /<\s*(div)[^>]*class\s*=\s*['"]note['"][^>]*>/

  def self.get_excerpt(html, length, options)
    html ||= ""
    length = html.length if html.include?("note") && CUSTOM_NOTE_REGEX === html
    me = self.new(length, options)
    parser = Nokogiri::HTML::SAX::Parser.new(me)
    catch(:done) { parser.parse(html) }
    excerpt = me.excerpt.strip
    excerpt = excerpt.gsub(/\s*\n+\s*/, "\n\n") if options[:keep_onebox_source] ||
      options[:keep_onebox_body]
    excerpt = CGI.unescapeHTML(excerpt) if options[:text_entities] == true
    excerpt
  end

  def start_element(name, attributes = [])
    super

    if name === "div" && attributes.include?(%w[class note])
      @excerpt = +""
      @current_length = 0
      @start_excerpt = true
    end
  end
end
