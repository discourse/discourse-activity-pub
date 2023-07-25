import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["activity-pub-visibility-dropdown"],

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

  actions: {
    onChange(value) {
      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
