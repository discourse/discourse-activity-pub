import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { clipboardCopy } from "discourse/lib/utilities";
import discourseLater from "discourse-common/lib/later";

export default class ActivityPubHandle extends Component {
  @service site;
  @service siteSettings;
  @tracked copied = false;

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
        {{#if @actor.url}}
          <a
            href={{@actor.url}}
            target="_blank"
            rel="noopener noreferrer"
            class="btn btn-icon no-text"
          >{{d-icon "external-link-alt"}}</a>
        {{/if}}
        {{#if this.copied}}
          <DButton @class="btn-hover" @icon="copy" @label="ip_lookup.copied" />
        {{else}}
          <DButton @action={{this.copy}} @class="no-text" @icon="copy" />
        {{/if}}
      </div>
    </div>
  </template>
}
