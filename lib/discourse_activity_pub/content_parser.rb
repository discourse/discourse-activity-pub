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
    discourse-local-dates
    text-post-process
  ]

  # Compare with https://docs.joinmastodon.org/spec/activitypub/#sanitization

  MARKDOWN_IT_RULES = %w[
    heading
    autolink
    list
    backticks
    code
    fence
    image
    linkify
    link
    blockquote
    emphasis
  ]

  PERMITTED_TAGS = %w[p a h1 h2 h3 h4 h5 ul ol li code blockquote em strong pre]

  MAX_TITLE_LENGTH = 60

  attr_reader :content

  def initialize(length, opts = {})
    @length = length
    @content = +""
    @current_length = 0
    @start_content = false
  end

  def start_element(name, attributes = [])
    case name
    when "p"
      start_tag(name, attributes)
      @in_p = true
    when "a"
      start_tag(name, attributes)
      @in_a = true
    when *PERMITTED_TAGS
      start_tag(name, attributes)
    when "div"
      if attributes.include?(%w[class note])
        @content = +""
        @current_length = 0
        @start_content = true
        start_tag("p", []) unless @in_p
      end
    end
  end

  def end_element(name)
    case name
    when "p"
      end_tag(name)
      @in_p = false
    when "a"
      end_tag(name)
      @in_a = false
    when *PERMITTED_TAGS
      end_tag(name)
    when "div"
      if @start_content
        end_tag("p")
        throw :done
      end
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
    if @length > 0 && (@current_length + string.length > @length)
      length = [0, @length - @current_length - 1].max
      @content << string[0..length]
      @content << "&hellip;"
      @content << "</a>" if @in_a
      @content << "</p>" if @in_p
      throw :done
    end
    @content << string
    @current_length += string.length
  end

  def self.cook(text, opts = {})
    html =
      PrettyText.markdown(
        text,
        opts.merge(features_override: MARKDOWN_FEATURES, markdown_it_rules: MARKDOWN_IT_RULES),
      )

    doc = Nokogiri::HTML5.fragment(html)

    # Support custom handling in plugins, e.g. local dates.
    DiscourseEvent.trigger(:reduce_excerpt, doc, opts)

    scrubber =
      Loofah::Scrubber.new do |node|
        node.remove if node.name == "script"
        node.content = node.content.gsub(%r{(\[note\]|\[/note\])}, "") if node.text?
      end
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
    length =
      if html.include?("note") && CUSTOM_NOTE_REGEX === html
        html.length
      else
        SiteSetting.activity_pub_note_excerpt_maxlength
      end
    parse(html, length)
  end

  def self.get_title(html)
    Loofah
      .fragment(html)
      .scrub!(:strip)
      .text
      .truncate(MAX_TITLE_LENGTH, separator: " ")
      .split(".")
      .first
  end

  def self.parse(html, length, opts = {})
    content_parser = self.new(length, opts)
    sax_parser = Nokogiri::HTML::SAX::Parser.new(content_parser, Encoding::UTF_8)
    catch(:done) { sax_parser.parse(html) }
    final_clean(content_parser.content.strip)
  end

  def self.final_clean(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.traverse do |node|
      if node.content.blank?
        node.remove
        next
      end
      node.content = node.content.gsub(/\n/, "").squeeze(" ") if node.text?
    end
    fragment.serialize(save_options: 0)
  end
end
