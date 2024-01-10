import { computed } from "@ember/object";
import I18n from "I18n";
import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  classNames: ["activity-pub-post-object-type-dropdown"],
  nameProperty: "label",

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
      this.onChange?.(value);
    },
  },
});
