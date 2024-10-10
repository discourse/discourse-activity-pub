export default {
  shouldRender(attrs, ctx) {
    return ctx.site.activity_pub_enabled;
  },
};
