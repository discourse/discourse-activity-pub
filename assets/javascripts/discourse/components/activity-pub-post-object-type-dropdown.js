import ComboBoxComponent from "select-kit/components/combo-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default ComboBoxComponent.extend({
  classNames: ["activity-pub-post-object-type-dropdown"],

  content: computed(function () {
    return [
      {
        id: "Note",
        label: I18n.t("discourse_activity_pub.post_object_type.label.note"),
        title: I18n.t(
          "discourse_activity_pub.post_object_type.description.note"
        ),
      },
      {
        id: "Article",
        label: I18n.t("discourse_activity_pub.post_object_type.label.article"),
        title: I18n.t(
          "discourse_activity_pub.post_object_type.description.article"
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
