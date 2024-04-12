export default {
  shouldRender(attrs, ctx) {
    return ctx.site.activity_pub_enabled;
  },

  setupComponent(attrs, component) {
    let model;
    let modelType;
    if (attrs.category) {
      model = attrs.category;
      modelType = "category";
    }
    if (attrs.tag) {
      model = attrs.tag;
      modelType = "tag";
    }
    component.setProperties({
      model,
      modelType,
    });
  },
};
