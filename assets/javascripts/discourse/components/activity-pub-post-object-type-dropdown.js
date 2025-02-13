import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";

@classNames("activity-pub-post-object-type-dropdown")
export default class ActivityPubPostObjectTypeDropdown extends ComboBoxComponent {
  nameProperty = "label";

  @computed
  get content() {
    return [
      {
        id: "Note",
        label: i18n("discourse_activity_pub.post_object_type.label.note"),
        title: i18n("discourse_activity_pub.post_object_type.description.note"),
      },
      {
        id: "Article",
        label: i18n("discourse_activity_pub.post_object_type.label.article"),
        title: i18n(
          "discourse_activity_pub.post_object_type.description.article"
        ),
      },
    ];
  }
}
