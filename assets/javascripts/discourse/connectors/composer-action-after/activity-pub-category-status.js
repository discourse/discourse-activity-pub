function showStatus(model) {
  return (
    model.get("category.activity_pub_ready") &&
    model.get("action") === "createTopic"
  );
}

export default {
  shouldRender(_, ctx) {
    return ctx.site.activity_pub_enabled;
  },

  setupComponent(attrs, component) {
    component.set("showStatus", showStatus(attrs.model));
    attrs.model.addObserver("category", () => {
      if (this._state === "destroying") {
        return;
      }
      component.set("showStatus", showStatus(attrs.model));
    });
  },
};
