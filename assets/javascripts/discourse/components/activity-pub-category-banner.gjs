import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ActivityPubHandle from "../components/activity-pub-handle";
import ActivityPubFollowBtn from "../components/activity-pub-follow-btn";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";

export default class ActivityPubCategoryBanner extends Component {
  @service site;

  get typeDescription() {
    if (this.args.category.activity_pub_default_visibility === "public") {
      if (this.args.category.activity_pub_publication_type === "full_topic") {
        return I18n.t("discourse_activity_pub.banner.public_full_topic");
      } else {
        return I18n.t("discourse_activity_pub.banner.public_first_post");
      }
    } else {
      if (this.args.category.activity_pub_publication_type === "full_topic") {
        return I18n.t(
          "discourse_activity_pub.banner.followers_only_full_topic"
        );
      } else {
        return I18n.t(
          "discourse_activity_pub.banner.followers_only_first_post"
        );
      }
    }
    return "";
  }

  <template>
    <div class="activity-pub-category-banner">
      {{#if @category}}
        <div class="activity-pub-category-banner-left">
          {{icon "discourse-activity-pub"}}
          <div class="activity-pub-category-banner-intro">
            {{i18n "discourse_activity_pub.banner.intro"}}
            {{this.typeDescription}}
          </div>
        </div>
        <div class="activity-pub-category-banner-right inline-form">
          <ActivityPubHandle @model={{@category}} />
          <ActivityPubFollowBtn @category={{@category}} />
        </div>
      {{/if}}
    </div>
  </template>
}
