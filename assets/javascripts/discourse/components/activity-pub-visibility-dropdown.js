import ComboBoxComponent from "select-kit/components/combo-box";
import I18n from "I18n";
import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";

export default ComboBoxComponent.extend({
  classNames: ["activity-pub-visibility-dropdown"],
  fullTopicPublication: equal("publicationType", "full_topic"),
  nameProperty: "label",

  content: computed(function () {
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
  }),

  didReceiveAttrs() {
    this._super(...arguments);

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
