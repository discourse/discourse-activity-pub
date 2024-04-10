import ActivityPubActor from "../../models/activity-pub-actor";

function showStatus(attrs, component) {
  const actor = ActivityPubActor.findByModel(
    attrs.model.get("category.id"),
    "category"
  );
  return (
    actor &&
    actor.ready &&
    attrs.model.get("action") === "createTopic" &&
    component.site.activity_pub_publishing_enabled
  );
}

export default {
  shouldRender(_, ctx) {
    return ctx.site.activity_pub_enabled;
  },

  setupComponent(attrs, component) {
    component.set("showStatus", showStatus(attrs, component));
    attrs.model.addObserver("category", () => {
      if (this._state === "destroying") {
        return;
      }
      component.set("showStatus", showStatus(attrs, component));
    });
  },
};
