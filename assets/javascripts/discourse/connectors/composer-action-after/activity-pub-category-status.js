function showStatus(attrs, component) {
  return (
    attrs.model.get("category.activity_pub_ready") &&
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
