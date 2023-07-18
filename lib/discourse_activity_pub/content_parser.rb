# frozen_string_literal: true

# TODO (future): PR discourse/discourse to support alternate excerpts

class DiscourseActivityPub::ContentParser < ExcerptParser
  CUSTOM_NOTE_REGEX = /<\s*(div)[^>]*class\s*=\s*['"]note['"][^>]*>/

  MARKDOWN_FEATURES = %w[
    activity-pub
    anchor
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
    me = self.new(length, {})
    parser = Nokogiri::HTML::SAX::Parser.new(me)
    catch(:done) { parser.parse(html) }
    me.excerpt.strip
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
