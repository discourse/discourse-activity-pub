import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["activity-pub-visibility-dropdown"],

  content: computed(function () {
    return [
      {
        id: "private",
        label: I18n.t("discourse_activity_pub.visibility.private.label"),
        title: I18n.t("discourse_activity_pub.visibility.private.description"),
      },
      {
        id: "public",
        label: I18n.t("discourse_activity_pub.visibility.public.label"),
        title: I18n.t("discourse_activity_pub.visibility.public.description"),
      },
    ];
  }),

  actions: {
    onChange(value) {
      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
