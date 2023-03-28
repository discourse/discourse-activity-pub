# frozen_string_literal: true

RSpec.describe DiscourseActivityPub::ExcerptParser do
  describe "#get_excerpt" do
    it "handles div note in short post" do
      expect(DiscourseActivityPub::ExcerptParser.get_excerpt("<div class='note'>hi</div> test", 100, {})).to eq("hi")
    end

    it "handles div note in long post" do
      html = <<~HTML
      <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis quam nulla, feugiat venenatis elementum ut, imperdiet eu nisl. Vestibulum dictum luctus tortor, vel consequat lectus tristique non. Sed aliquam at eros et lacinia. Nam viverra libero at tortor semper fringilla non ut velit. Mauris dignissim sapien sed felis consequat, quis ullamcorper augue viverra. Donec elementum nisl ut leo viverra, vel consequat diam facilisis. Donec leo arcu, dictum vel vestibulum sit amet, maximus sed neque. Vestibulum blandit metus ante, sit amet porta lorem maximus id. Suspendisse sed lacus sapien. Nulla dui dui, dapibus vitae quam ut, elementum ultrices ipsum. In congue laoreet eleifend. Sed tincidunt consequat dolor, volutpat posuere arcu molestie a. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos.</p>
<p>Pellentesque feugiat, elit ut aliquam fringilla, lectus eros rhoncus arcu, eget posuere ex velit ac purus. Morbi nec enim iaculis, lobortis lacus id, laoreet neque. Pellentesque et turpis a sapien tincidunt consequat quis a urna. Curabitur id ipsum vitae nisi dapibus tincidunt. Cras hendrerit nunc eget consectetur dapibus. Donec lacinia in sapien ac pellentesque. Phasellus at risus et lorem luctus pretium a eget leo. Nulla pellentesque metus libero, sit amet efficitur diam vehicula ac. Mauris ultrices erat non nulla volutpat tristique et sed arcu. </p><div class="note">hi</div><p></p>
      HTML
      expect(DiscourseActivityPub::ExcerptParser.get_excerpt(html, 100, {})).to eq("hi")
    end
  end
end