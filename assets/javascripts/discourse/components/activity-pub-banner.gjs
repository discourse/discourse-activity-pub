import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import ActivityPubFollowBtn from "./activity-pub-follow-btn";
import ActivityPubHandle from "./activity-pub-handle";

export default class ActivityPubBanner extends Component {
  @service site;

  get bannerDescription() {
    const visibility = this.args.actor.default_visibility;
    const publicationType = this.args.actor.publication_type;
    return i18n(
      `discourse_activity_pub.banner.${visibility}_${publicationType}`
    );
  }

  get responsiveText() {
    return i18n("discourse_activity_pub.banner.responsive_text");
  }

  get desktopText() {
    return i18n("discourse_activity_pub.banner.text", {
      model_name: this.args.actor.model.name,
    });
  }

  <template>
    <div class="activity-pub-banner">
      {{#if @actor}}
        <div class="activity-pub-banner-left activity-pub-banner-side">
          <DTooltip
            @icon="discourse-activity-pub"
            @content={{this.bannerDescription}}
          />
          <div class="activity-pub-banner-text">
            <span class="desktop">{{this.desktopText}}</span>
            <span class="responsive">{{this.responsiveText}}</span>
          </div>
        </div>
        <div class="activity-pub-banner-right activity-pub-banner-side">
          {{#unless this.site.mobileView}}
            <ActivityPubHandle @actor={{@actor}} />
          {{/unless}}
          <ActivityPubFollowBtn @actor={{@actor}} @type="follow" />
        </div>
      {{/if}}
    </div>
  </template>
}
