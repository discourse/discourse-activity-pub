import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import ActivityPubFollowBtn from "./activity-pub-follow-btn";
import ActivityPubHandle from "./activity-pub-handle";

export default class ActivityPubCategoryBanner extends Component {
  @service site;

  get bannerDescription() {
    const visibility = this.args.category.activity_pub_default_visibility;
    const publicationType = this.args.category.activity_pub_publication_type;
    return I18n.t(
      `discourse_activity_pub.banner.${visibility}_${publicationType}`
    );
  }

  get responsiveText() {
    return I18n.t("discourse_activity_pub.banner.responsive_text", {
      category_name: this.args.category.name,
    });
  }

  get desktopText() {
    return I18n.t("discourse_activity_pub.banner.text", {
      category_name: this.args.category.name,
    });
  }

  <template>
    <div class="activity-pub-category-banner">
      {{#if @category}}
        <div
          class="activity-pub-category-banner-left activity-pub-category-banner-side"
        >
          <DTooltip
            @icon="discourse-activity-pub"
            @content={{this.bannerDescription}}
          />
          <div class="activity-pub-category-banner-text">
            <span class="desktop">{{this.desktopText}}</span>
            <span class="responsive">{{this.responsiveText}}</span>
          </div>
        </div>
        <div
          class="activity-pub-category-banner-right activity-pub-category-banner-side"
        >
          {{#unless this.site.mobileView}}
            <ActivityPubHandle @actor={{@category.activity_pub_actor}} />
          {{/unless}}
          <ActivityPubFollowBtn
            @actor={{@category.activity_pub_actor}}
            @type="follow"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
