# frozen_string_literal: true

class DiscourseActivityPub::ContentParser < Nokogiri::XML::SAX::Document
  CUSTOM_NOTE_REGEX = /<\s*(div)[^>]*class\s*=\s*['"]note['"][^>]*>/

  MARKDOWN_FEATURES = %w[
    activity-pub
    bbcode-block
    bbcode-inline
    code
    censored
    emoji
    emojiShortcuts
    inlineEmoji
    html-img
    unicodeUsernames
    quotes
    upload-protocol
    watched-words
  ]

  # Compare with https://docs.joinmastodon.org/spec/activitypub/#sanitization

  MARKDOWN_IT_RULES = %w[
    heading
    autolink
    list
    backticks
    newline
    code
    fence
    image
    linkify
    link
    blockquote
    emphasis
  ]

  attr_reader :content

  def initialize(length)
    @length = length
    @content = +""
    @current_length = 0
    @start_content = false
  end

  def start_element(name, attributes = [])
    case name
    when "a"
      start_tag(name, attributes)
      @in_a = true
    when "h1", "h2", "h3", "h4", "h5"
      start_tag(name, attributes)
    when "div"
      if attributes.include?(%w[class note])
        @content = +""
        @current_length = 0
        @start_content = true
      end
    end
  end

  def end_element(name)
    case name
    when "a"
      end_tag(name)
      @in_a = false
    when "h1", "h2", "h3", "h4", "h5"
      end_tag(name)
    when "div"
      throw :done if @start_content
    end
  end

  def escape_attribute(v)
    return "" unless v

    v = v.dup
    v.gsub!("&", "&amp;")
    v.gsub!("\"", "&#34;")
    v.gsub!("<", "&lt;")
    v.gsub!(">", "&gt;")
    v
  end

  def start_tag(name, attributes)
    tag = name
    attrs = attributes.map { |k, v| "#{k}=\"#{escape_attribute(v)}\"" }.join(" ")
    tag += " #{attrs}" if attrs.present?
    characters("<#{tag}>")
  end

  def end_tag(name)
    characters("</#{name}>")
  end

  def characters(string)
    if @current_length + string.length > @length
      length = [0, @length - @current_length - 1].max
      @content << string[0..length]
      @content << "&hellip;"
      @content << "</a>" if @in_a
      throw :done
    end
    @content << string
    @current_length += string.length
  end

  def self.cook(text, opts = {})
    html = PrettyText.markdown(
      text,
      opts.merge(
        features_override: MARKDOWN_FEATURES,
        markdown_it_rules: MARKDOWN_IT_RULES,
      )
    )
    scrubbed_html(html)
  end

  def self.scrubbed_html(html)
    doc = Nokogiri::HTML5.fragment(html)
    scrubber = Loofah::Scrubber.new { |node| node.remove if node.name == "script" }
    loofah_fragment = Loofah.html5_fragment(doc.to_html)
    loofah_fragment.scrub!(scrubber).to_html
  end

  def self.get_content(post)
    html = cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
    type = post.activity_pub_object_type.downcase
    return nil unless self.respond_to?("get_#{type}") && html
    self.send("get_#{type}", html)
  end

  def self.get_article(html)
    html
  end

  def self.get_note(html)
    length = if html.include?("note") && CUSTOM_NOTE_REGEX === html
               html.length
             else
               SiteSetting.activity_pub_note_excerpt_maxlength
             end
    content_parser = self.new(length)
    sax_parser = Nokogiri::HTML::SAX::Parser.new(content_parser)
    catch(:done) { sax_parser.parse(html) }
    content_parser.content.strip
  end
end
