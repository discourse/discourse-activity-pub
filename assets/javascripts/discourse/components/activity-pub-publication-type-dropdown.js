import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["activity-pub-publication-type-dropdown"],

  content: computed(function () {
    return [
      {
        id: "first_post",
        label: I18n.t("discourse_activity_pub.publication_type.first_post.label"),
        title: I18n.t(
          "discourse_activity_pub.publication_type.first_post.description"
        ),
      },
      {
        id: "full_topic",
        label: I18n.t("discourse_activity_pub.publication_type.full_topic.label"),
        title: I18n.t(
          "discourse_activity_pub.publication_type.full_topic.description"
        ),
      },
    ];
  }),

  actions: {
    onChange(value) {
      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
