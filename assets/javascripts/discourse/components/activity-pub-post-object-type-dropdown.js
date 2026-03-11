import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

@classNames("activity-pub-post-object-type-dropdown")
export default class ActivityPubPostObjectTypeDropdown extends ComboBoxComponent {
  nameProperty = "label";

  @computed
  get content() {
    return [
      {
        id: "Note",
        label: i18n("discourse_activity_pub.object_type.label.note"),
        title: i18n("discourse_activity_pub.object_type.description.note"),
      },
      {
        id: "Article",
        label: i18n("discourse_activity_pub.object_type.label.article"),
        title: i18n("discourse_activity_pub.object_type.description.article"),
      },
    ];
  }
}
