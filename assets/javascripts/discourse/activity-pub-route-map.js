export default function () {
  this.route(
    "activityPub",
    {
      path: "/ap",
      resetNamespace: true,
    },
    function () {
      this.route("about");
      this.route(
        "actor",
        {
          path: "/local/actor/:actor_id",
        },
        function () {
          this.route("followers");
          this.route("follows");
        }
      );
    }
  );
}
