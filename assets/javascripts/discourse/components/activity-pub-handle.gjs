import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import discourseLater from "discourse/lib/later";
import { clipboardCopy } from "discourse/lib/utilities";

export default class ActivityPubHandle extends Component {
  @tracked copied = false;

  get showLink() {
    return this.args.actor?.url && !this.args.hideLink;
  }

  @action
  copy() {
    clipboardCopy(this.args.actor.handle);
    this.copied = true;
    discourseLater(() => {
      this.copied = false;
    }, 2000);
  }

  <template>
    <div class="activity-pub-handle">
      <div class="activity-pub-handle-contents">
        <span class="handle">{{@actor.handle}}</span>
        {{#if this.showLink}}
          <a
            href={{@actor.url}}
            target="_blank"
            rel="noopener noreferrer"
            class="btn btn-icon no-text"
          >{{icon "up-right-from-square"}}</a>
        {{/if}}
        {{#unless @hideCopy}}
          {{#if this.copied}}
            <DButton @icon="copy" @label="ip_lookup.copied" class="btn-hover" />
          {{else}}
            <DButton @action={{this.copy}} @icon="copy" class="no-text" />
          {{/if}}
        {{/unless}}
      </div>
    </div>
  </template>
}
