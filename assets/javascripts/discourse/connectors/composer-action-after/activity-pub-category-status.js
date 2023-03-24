function showStatus(model) {
  return (
    model.get("category.activity_pub_show_status") &&
    model.get("action") === "createTopic"
  );
}

export default {
  shouldRender(_, ctx) {
    return (
      !ctx.siteSettings.login_required && ctx.siteSettings.activity_pub_enabled
    );
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
