# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ContentParser do
  describe "#get_note" do
    it "handles div note in short post" do
      expect(described_class.get_note("<div class='note'>hi</div> test")).to eq("<p>hi</p>")
    end

    it "handles div note in long post" do
      html = <<~HTML
      <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis quam nulla, feugiat venenatis elementum ut, imperdiet eu nisl. Vestibulum dictum luctus tortor, vel consequat lectus tristique non. Sed aliquam at eros et lacinia. Nam viverra libero at tortor semper fringilla non ut velit. Mauris dignissim sapien sed felis consequat, quis ullamcorper augue viverra. Donec elementum nisl ut leo viverra, vel consequat diam facilisis. Donec leo arcu, dictum vel vestibulum sit amet, maximus sed neque. Vestibulum blandit metus ante, sit amet porta lorem maximus id. Suspendisse sed lacus sapien. Nulla dui dui, dapibus vitae quam ut, elementum ultrices ipsum. In congue laoreet eleifend. Sed tincidunt consequat dolor, volutpat posuere arcu molestie a. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos.</p>
<p>Pellentesque feugiat, elit ut aliquam fringilla, lectus eros rhoncus arcu, eget posuere ex velit ac purus. Morbi nec enim iaculis, lobortis lacus id, laoreet neque. Pellentesque et turpis a sapien tincidunt consequat quis a urna. Curabitur id ipsum vitae nisi dapibus tincidunt. Cras hendrerit nunc eget consectetur dapibus. Donec lacinia in sapien ac pellentesque. Phasellus at risus et lorem luctus pretium a eget leo. Nulla pellentesque metus libero, sit amet efficitur diam vehicula ac. Mauris ultrices erat non nulla volutpat tristique et sed arcu. </p><div class="note">hi</div><p></p>
      HTML
      expect(described_class.get_note(html)).to eq("<p>hi</p>")
    end
  end

  describe "#get_content" do
    it "respects the maxlength site setting for note excerpts" do
      SiteSetting.activity_pub_note_excerpt_maxlength = 10
      expected_excerpt = "This is&hellip;"
      post = Fabricate(:post_with_long_raw_content)
      post.rebake!
      expect(described_class.get_content(post)).to eq("<p>This is…</p>")
    end

    it "does not apply a maxlength if the site setting is 0" do
      SiteSetting.activity_pub_note_excerpt_maxlength = 0
      post = Fabricate(:post_with_long_raw_content)
      post.rebake!
      expect(described_class.get_content(post)).to eq(
        "<p>This is a sample post with semi-long raw content. The raw content is also more than two hundred characters to satisfy any test conditions that require content longer than the typical test post raw content. It really is some long content, folks.</p>",
      )
    end

    it "respects [note] tags" do
      content = "[note]This plugin is being developed[/note] by #pavilion for #Discourse"
      post = Fabricate(:post, raw: content)
      expect(described_class.get_content(post)).to eq("<p>This plugin is being developed</p>")
    end

    it "handles line breaks" do
      content = <<~STRING
        [note]
        First line

        Second line
        [/note]

        Third line
      STRING
      post = Fabricate(:post, raw: content)
      expect(described_class.get_content(post)).to eq("<p>First line</p><p>Second line</p>")
    end

    it "handles invalid line breaks" do
      # See https://meta.discourse.org/t/discourse-commonmark-migration-plans-confetti-ball-balloon/64234/6?u=angus
      content = <<~STRING
        [note]First line

        Second line[/note]

        Third line
      STRING
      post = Fabricate(:post, raw: content)
      expect(described_class.get_content(post)).to eq(
        "<p>First line</p><p>Second line</p><p>Third line</p>",
      )
    end

    it "does not convert local hashtags" do
      Fabricate(:category, name: "pavilion")
      Fabricate(:tag, name: "Discourse")
      content = "This plugin is being developed by #pavilion for #Discourse"
      post = Fabricate(:post, raw: content)
      expect(described_class.get_content(post)).to eq("<p>#{content}</p>")
    end

    it "does not convert local mentions" do
      Fabricate(:user, username: "angus")
      content = "This plugin is being developed by @angus@mastodon.pavilion.tech"
      post = Fabricate(:post, raw: content)
      expect(described_class.get_content(post)).to eq("<p>#{content}</p>")
    end

    it "handles local dates" do
      content = '[date=2019-10-16 time=14:00:00 format="LLLL" timezone="America/New_York"]'
      post = Fabricate(:post, raw: content)
      expect(described_class.get_content(post)).to eq(
        "<p>Wednesday, October 16, 2019 6:00 PM (UTC)</p>",
      )
    end

    context "with Article" do
      it "returns all cooked content" do
        Post.any_instance.stubs(:activity_pub_object_type).returns("Article")
        post = Fabricate(:post_with_very_long_raw_content)
        expect(described_class.get_content(post)).to eq(described_class.cook(post.raw))
      end
    end

    context "with Note" do
      before { Post.any_instance.stubs(:activity_pub_object_type).returns("Note") }

      context "with markdown" do
        let(:raw_markdown) { <<~STRING }
          # First Header

          ## Second Header

          ### Third Header

          #### Fourth Header

          Paragraph

          [Link](https://discourse.org)

          > This is a quote

          - This is an unordered list item

          1. This is an ordered list item

          ``This is a code block``

          **This is strong text**

          *This is emphasised text*

          ```js
          [] == ![]; // true
           !!"false" == !!"true"; // true
           NaN === NaN; // false
          ```

          STRING
        let(:cooked_markdown) { <<~HTML }
          <h1>First Header</h1>
          <h2>Second Header</h2>
          <h3>Third Header</h3>
          <h4>Fourth Header</h4>
          <p>Paragraph</p>
          <p><a href="https://discourse.org">Link</a></p>
          <blockquote>
          <p>This is a quote</p>
          </blockquote>
          <ul>
          <li>This is an unordered list item</li>
          </ul>
          <ol>
          <li>This is an ordered list item</li>
          </ol>
          <p><code>This is a code block</code></p>
          <p><strong>This is strong text</strong></p>
          <p><em>This is emphasised text</em></p>
          <pre data-code-wrap="js"><code class="lang-js">[] == ![]; // true
           !!"false" == !!"true"; // true
           NaN === NaN; // false
          </code></pre>
          HTML
        let!(:post) { Fabricate(:post, raw: raw_markdown) }

        before { SiteSetting.activity_pub_note_excerpt_maxlength = 1000 }

        it "returns html" do
          expect(described_class.get_content(post)).to eq(
            described_class.final_clean(cooked_markdown),
          )
        end
      end

      context "with unicode in raw" do
        let!(:post) { Fabricate(:post, raw: "fürry österreich") }

        it "returns unicode content" do
          expect(described_class.get_content(post)).to eq("<p>fürry österreich</p>")
        end
      end
    end
  end

  describe "#get_title" do
    it "does not add &hellip; to titles" do
      html = <<~HTML
      <p>Lorem ipsum dolor sit amet consectetur adipiscing elit pos. Duis quam nulla, feugiat venenatis elementum ut, imperdiet eu nisl. Vestibulum dictum luctus tortor, vel consequat lectus tristique non. Sed aliquam at eros et lacinia.</p>
      HTML
      expect(described_class.get_title(html)).to eq(
        "Lorem ipsum dolor sit amet consectetur adipiscing elit",
      )
    end

    it "removes markup from title text" do
      html = <<~HTML
      <p>Lorem <a href="meta.discourse.org">ipsum dolor sit amet</a> consectetur adipiscing elit pos. Duis quam nulla, feugiat venenatis elementum ut, imperdiet eu nisl. Vestibulum dictum luctus tortor, vel consequat lectus tristique non. Sed aliquam at eros et lacinia.</p>
      HTML
      expect(described_class.get_title(html)).to eq(
        "Lorem ipsum dolor sit amet consectetur adipiscing elit",
      )
    end

    it "stops at periods" do
      html = <<~HTML
      <p>Lorem ipsum dolor sit amet consectetur. adipiscing elit pos Duis quam nulla, feugiat venenatis elementum ut, imperdiet eu nisl. Vestibulum dictum luctus tortor, vel consequat lectus tristique non. Sed aliquam at eros et lacinia.</p>
      HTML
      expect(described_class.get_title(html)).to eq("Lorem ipsum dolor sit amet consectetur")
    end
  end
end
