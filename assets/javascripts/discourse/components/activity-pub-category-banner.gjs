import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ActivityPubHandle from "../components/activity-pub-handle";
import ActivityPubFollowBtn from "../components/activity-pub-follow-btn";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";
import DTooltip from "float-kit/components/d-tooltip";

export default class ActivityPubCategoryBanner extends Component {
  @service site;

  get bannerDescription() {
    const visibility = this.args.category.activity_pub_default_visibility;
    const publicationType = this.args.category.activity_pub_publication_type;
    return I18n.t(`discourse_activity_pub.banner.${visibility}_${publicationType}`);
  }

  get bannerText() {
    const key = this.site.mobileView ? 'mobile_text' : 'text';
    return I18n.t(`discourse_activity_pub.banner.${key}`, {
      category_name: this.args.category.name
    });
  }

  <template>
    <div class="activity-pub-category-banner">
      {{#if @category}}
        <div class="activity-pub-category-banner-left activity-pub-category-banner-side">
          <DTooltip
            @icon="discourse-activity-pub"
            @content={{this.bannerDescription}}
          />
          <span class="activity-pub-category-banner-text">
            {{this.bannerText}}
          </span>
        </div>
        <div class="activity-pub-category-banner-right activity-pub-category-banner-side">
          {{#unless this.site.mobileView}}
            <ActivityPubHandle @actor={{@category.activity_pub_actor}} />
          {{/unless}}
          <ActivityPubFollowBtn @actor={{@category.activity_pub_actor}} @type="follow" />
        </div>
      {{/if}}
    </div>
  </template>
}
