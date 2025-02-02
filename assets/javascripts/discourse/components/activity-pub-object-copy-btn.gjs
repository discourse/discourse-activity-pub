import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class ActivityPubObjectCopyBtn extends Component {
  @tracked copiedObjectId = false;

  @action
  copyObjectId() {
    clipboardCopy(this.args.object.activity_pub_object_id);
    this.copiedObjectId = true;
    setTimeout(() => {
      this.copiedObjectId = false;
    }, 2500);
  }

  get show() {
    return this.args.object.activity_pub_object_id;
  }

  get copyObjectIdLabel() {
    let objectType = this.args.object.activity_pub_object_type;
    if (objectType.includes("Collection")) {
      objectType = "Collection";
    }
    return i18n("discourse_activity_pub.copy_uri.label", {
      object_type: objectType,
    });
  }

  <template>
    {{#if this.show}}
      <DButton
        @icon="copy"
        @action={{this.copyObjectId}}
        @translatedLabel={{this.copyObjectIdLabel}}
        class="activity-pub-object-id-copy"
      >
        {{#if this.copiedObjectId}}
          <div class="activity-pub-object-id-copy-text">
            {{i18n "discourse_activity_pub.copy_uri.copied"}}
          </div>
        {{/if}}
      </DButton>
    {{/if}}
  </template>
}
