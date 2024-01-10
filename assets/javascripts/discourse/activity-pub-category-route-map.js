export default function () {
  this.route(
    "activityPub.category",
    {
      path: "/ap/category/:category_id",
      resetNamespace: true,
    },
    function () {
      this.route("followers");
      this.route("follows");
    }
  );
}
