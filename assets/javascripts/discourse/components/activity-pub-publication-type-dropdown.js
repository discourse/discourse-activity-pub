import { computed } from "@ember/object";
import I18n from "I18n";
import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  classNames: ["activity-pub-publication-type-dropdown"],
  nameProperty: "label",

  content: computed(function () {
    return [
      {
        id: "first_post",
        label: I18n.t(
          "discourse_activity_pub.publication_type.label.first_post"
        ),
        title: I18n.t(
          "discourse_activity_pub.publication_type.description.first_post"
        ),
      },
      {
        id: "full_topic",
        label: I18n.t(
          "discourse_activity_pub.publication_type.label.full_topic"
        ),
        title: I18n.t(
          "discourse_activity_pub.publication_type.description.full_topic"
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
