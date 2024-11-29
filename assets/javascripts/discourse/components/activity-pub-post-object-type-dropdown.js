import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "I18n";
import ComboBoxComponent from "select-kit/components/combo-box";

@classNames("activity-pub-post-object-type-dropdown")
export default class ActivityPubPostObjectTypeDropdown extends ComboBoxComponent {
  nameProperty = "label";

  @computed
  get content() {
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
  }
}
