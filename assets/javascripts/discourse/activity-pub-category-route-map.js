export default function () {
  this.route(
    "activityPub.category",
    {
      path: "/ap/category/:category_id",
      resetNamespace: true,
    },
    function () {
      this.route("followers", { path: "followers" });
      this.route("follows", { path: "follows" });
    }
  );
}
