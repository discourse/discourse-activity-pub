import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";

@classNames("activity-pub-publication-type-dropdown")
export default class ActivityPubPublicationTypeDropdown extends ComboBoxComponent {
  nameProperty = "label";

  @computed
  get content() {
    return [
      {
        id: "first_post",
        label: i18n("discourse_activity_pub.publication_type.label.first_post"),
        title: i18n(
          "discourse_activity_pub.publication_type.description.first_post",
          {
            model_type: this.modelType,
          }
        ),
      },
      {
        id: "full_topic",
        label: i18n("discourse_activity_pub.publication_type.label.full_topic"),
        title: i18n(
          "discourse_activity_pub.publication_type.description.full_topic",
          {
            model_type: this.modelType,
          }
        ),
      },
    ];
  }
}
