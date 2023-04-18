# frozen_string_literal: true

# TODO (future): PR discourse/discourse to support alternate excerpts

class DiscourseActivityPub::ExcerptParser < ExcerptParser
  CUSTOM_NOTE_REGEX = /<\s*(div)[^>]*class\s*=\s*['"]note['"][^>]*>/

  def self.get_content(post)
    cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
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
