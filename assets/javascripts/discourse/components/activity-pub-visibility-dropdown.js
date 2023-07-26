import ComboBoxComponent from "select-kit/components/combo-box";
import I18n from "I18n";
import { computed } from "@ember/object";
import { observes, on } from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";

export default DropdownSelectBoxComponent.extend({
  classNames: ["activity-pub-visibility-dropdown", "activity-pub-dropdown"],
  fullTopicPublication: equal("publicationType", "full_topic"),

  content: computed(function () {
    return [
      {
        id: "private",
        label: I18n.t("discourse_activity_pub.visibility.label.private"),
        title: I18n.t("discourse_activity_pub.visibility.description.private"),
      },
      {
        id: "public",
        label: I18n.t("discourse_activity_pub.visibility.label.public"),
        title: I18n.t("discourse_activity_pub.visibility.description.public"),
      },
    ];
  }),

  @on("didReceiveAttrs")
  @observes("fullTopicPublication")
  handleFullTopicPublication() {
    if (this.fullTopicPublication) {
      this.set("value", "public");
    }
    scheduleOnce("afterRender", () => {
      this.set("selectKit.options.disabled", this.fullTopicPublication);
    });
  },

  actions: {
    onChange(value) {
      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
