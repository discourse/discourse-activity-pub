# frozen_string_literal: true

# TODO (future): PR discourse/discourse to support alternate excerpts

class DiscourseActivityPub::ExcerptParser < ExcerptParser
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
    doc = Nokogiri::HTML5.fragment(html)
    scrubbed_html(doc)
  end

  def self.scrubbed_html(doc)
    scrubber = Loofah::Scrubber.new { |node| node.remove if node.name == "script" }
    loofah_fragment = Loofah.html5_fragment(doc.to_html)
    loofah_fragment.scrub!(scrubber).to_html
  end

  def self.get_content(post)
    cooked = cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
    max_length = SiteSetting.activity_pub_note_excerpt_maxlength
    get_excerpt(cooked, max_length, post: post)
  end

  def self.get_excerpt(html, length, options)
    html ||= ""
    length = html.length if html.include?("note") && CUSTOM_NOTE_REGEX === html
    me = self.new(length, options)
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
