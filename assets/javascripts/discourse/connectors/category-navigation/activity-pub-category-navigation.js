export default {
  shouldRender(_, ctx) {
    return ctx.site.activity_pub_enabled;
  },
};
