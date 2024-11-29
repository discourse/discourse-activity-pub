import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import I18n from "I18n";
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
        label: I18n.t("discourse_activity_pub.visibility.label.private"),
        title: I18n.t("discourse_activity_pub.visibility.description.private", {
          object_type: this.objectType,
        }),
      },
      {
        id: "public",
        label: I18n.t("discourse_activity_pub.visibility.label.public"),
        title: I18n.t("discourse_activity_pub.visibility.description.public", {
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
