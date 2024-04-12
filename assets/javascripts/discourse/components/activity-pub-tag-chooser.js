import { computed } from "@ember/object";
import TagDrop from "select-kit/components/tag-drop";
import ActivityPubActor from "../models/activity-pub-actor";

export default TagDrop.extend({
  classNames: ["activity-pub-tag-chooser"],

  content: computed("topTags.[]", function () {
    return this.activityPubFilter(this.topTags);
  }),

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

  search(filter) {
    return this.activityPubFilter(this._super(filter));
  },

  actions: {
    onChange(tagId) {
      this.onChange(tagId);
    },
  },
});
