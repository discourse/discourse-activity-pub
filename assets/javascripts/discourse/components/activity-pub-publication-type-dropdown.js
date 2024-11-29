import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "I18n";
import ComboBoxComponent from "select-kit/components/combo-box";

@classNames("activity-pub-publication-type-dropdown")
export default class ActivityPubPublicationTypeDropdown extends ComboBoxComponent {
  nameProperty = "label";

  @computed
  get content() {
    return [
      {
        id: "first_post",
        label: I18n.t(
          "discourse_activity_pub.publication_type.label.first_post"
        ),
        title: I18n.t(
          "discourse_activity_pub.publication_type.description.first_post",
          {
            model_type: this.modelType,
          }
        ),
      },
      {
        id: "full_topic",
        label: I18n.t(
          "discourse_activity_pub.publication_type.label.full_topic"
        ),
        title: I18n.t(
          "discourse_activity_pub.publication_type.description.full_topic",
          {
            model_type: this.modelType,
          }
        ),
      },
    ];
  }
}
