import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";

@classNames("activity-pub-visibility-dropdown")
export default class ActivityPubVisibilityDropdown extends ComboBoxComponent {
  @equal("publicationType", "full_topic") fullTopicPublication;

  nameProperty = "label";

  @computed
  get content() {
    return [
      {
        id: "private",
        label: i18n("discourse_activity_pub.visibility.label.private"),
        title: i18n("discourse_activity_pub.visibility.description.private", {
          object_type: this.objectType,
        }),
      },
      {
        id: "public",
        label: i18n("discourse_activity_pub.visibility.label.public"),
        title: i18n("discourse_activity_pub.visibility.description.public", {
          object_type: this.objectType,
        }),
      },
    ];
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.fullTopicPublication) {
      this.set("value", "public");
    }
    schedule("afterRender", () => {
      this.set("selectKit.options.disabled", this.fullTopicPublication);
    });
  }
}
