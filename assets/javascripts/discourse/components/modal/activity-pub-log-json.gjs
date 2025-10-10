import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import formatDate from "discourse/helpers/format-date";
import discourseLater from "discourse/lib/later";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class ActivityPubLogJson extends Component {
  @tracked copied = false;

  get jsonDisplay() {
    return JSON.stringify(this.args.model.log.json, null, 4);
  }

  @action
  copyToClipboard() {
    clipboardCopy(this.args.model.log.json);
    this.copied = true;
    discourseLater(() => {
      this.copied = false;
    }, 3000);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "admin.discourse_activity_pub.log.json.title"}}
      class="activity-pub-json-modal"
    >
      <:body>
        <div class="activity-pub-json-modal-header">
          <div class="activity-pub-json-modal-title">
            {{htmlSafe
              (i18n
                "admin.discourse_activity_pub.log.json.logged_at"
                logged_at=(formatDate
                  @model.log.created_at format="medium" leaveAgo="true"
                )
              )
            }}
          </div>
          <div class="activity-pub-json-modal-buttons">
            {{#if this.copied}}
              <span class="activity-pub-json-copy-status success">
                {{i18n "admin.discourse_activity_pub.log.json.copy.success"}}
              </span>
            {{/if}}
            <DButton
              @action={{this.copyToClipboard}}
              @icon="copy"
              @label="admin.discourse_activity_pub.log.json.copy.label"
              @title="admin.discourse_activity_pub.log.json.copy.title"
              class="activity-pub-json-copy-btn btn-default"
            />
          </div>
        </div>
        <pre class="activity-pub-json-display">{{this.jsonDisplay}}</pre>
      </:body>
    </DModal>
  </template>
}
