import I18n from "I18n";
import TagDrop, {
  ALL_TAGS_ID,
  NO_TAG_ID,
  NONE_TAG,
} from "select-kit/components/tag-drop";
import ActivityPubActor from "../models/activity-pub-actor";

export default TagDrop.extend({
  classNames: ["activity-pub-tag-chooser"],

  selectKitOptions: {
    hasActor: false,
  },

  activityPubFilter(tags) {
    return tags.filter((tag) => {
      if (tag === this.tagId) {
        return false;
      }
      const actor = ActivityPubActor.findByModel(tag, "tag");
      if (this.selectKit.options.hasActor) {
        return !!actor;
      } else {
        return !actor;
      }
    });
  },

  modifyContent(content) {
    return this.activityPubFilter(content);
  },

  modifyNoSelection() {
    if (this.tagId === NONE_TAG) {
      return this.defaultItem(
        NO_TAG_ID,
        I18n.t("admin.discourse_activity_pub.actor.tag.none")
      );
    } else {
      return this.defaultItem(
        ALL_TAGS_ID,
        I18n.t("admin.discourse_activity_pub.actor.tag.none")
      );
    }
  },

  actions: {
    onChange(tagId) {
      this.onChange(tagId);
    },
  },
});
