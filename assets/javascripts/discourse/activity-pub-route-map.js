export default function () {
  this.route(
    "activityPub",
    {
      path: "/ap/local",
      resetNamespace: true,
    },
    function () {
      this.route("about");
      this.route(
        "actor",
        {
          path: "/actor/:actor_id",
        },
        function () {
          this.route("followers");
          this.route("follows");
        }
      );
    }
  );
}
