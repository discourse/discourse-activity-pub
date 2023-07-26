import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: [
    "activity-pub-post-object-type-dropdown",
    "activity-pub-dropdown",
  ],

  content: computed(function () {
    return [
      {
        id: "Note",
        label: I18n.t("discourse_activity_pub.post_object_type.note.label"),
        title: I18n.t(
          "discourse_activity_pub.post_object_type.note.description"
        ),
      },
      {
        id: "Article",
        label: I18n.t("discourse_activity_pub.post_object_type.article.label"),
        title: I18n.t(
          "discourse_activity_pub.post_object_type.article.description"
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
